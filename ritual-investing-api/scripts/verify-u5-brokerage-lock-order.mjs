import pg from "pg";

const databaseUrl = process.env.ARGUS_LOCAL_DATABASE_URL ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const parsedUrl = new URL(databaseUrl);
if (!["127.0.0.1", "localhost", "::1"].includes(parsedUrl.hostname)) {
  throw new Error("U5 lock verification refuses non-local databases");
}

const pool = new pg.Pool({ connectionString: databaseUrl, max: 20 });
const userId = "54545454-5454-4545-8545-545454545454";
const sessionId = "54545454-0000-4000-8000-000000000001";
const connectionId = "54545454-1000-4000-8000-000000000001";
const accountIds = Array.from(
  { length: 16 },
  (_, index) =>
    `54545454-2000-4000-8000-${String(index + 1).padStart(12, "0")}`,
);
const commandIds = Array.from(
  { length: 16 },
  (_, index) =>
    `54545454-7000-4000-8000-${String(index + 1).padStart(12, "0")}`,
);
const accountId = accountIds[0];
const harnessRoles = [
  "argus_brokerage_owner",
  "argus_identity_owner",
  "argus_edge",
];
const brokerageHarnessPolicies = [
  ["u5_lock_harness_connection_insert", "argus_brokerage.connections"],
  ["u5_lock_harness_connection_delete", "argus_brokerage.connections"],
  ["u5_lock_harness_account_insert", "argus_brokerage.accounts"],
  ["u5_lock_harness_credential_insert", "argus_private.webull_credentials"],
  ["u5_lock_harness_command_delete", "argus_private.provider_commands"],
  ["u5_lock_harness_attempt_delete", "argus_private.provider_command_attempts"],
  ["u5_lock_harness_reconciliation_delete", "argus_private.reconciliation_records"],
];
const identityHarnessPolicies = [
  ["u5_lock_harness_lifecycle_delete", "argus_app.member_lifecycles"],
];
const harnessPolicies = [
  ...brokerageHarnessPolicies,
  ...identityHarnessPolicies,
];

async function installHarnessAccess(client) {
  await client.query("begin");
  try {
    const actor = await client.query("select current_user actor");
    if (actor.rows[0]?.actor !== "postgres") {
      throw new Error("U5 lock verification requires the local postgres fixture role");
    }
    // Remove only prior postgres-grantor residue. The installer intentionally
    // retains supabase_admin-grantor memberships with SET/INHERIT false; this
    // harness must preserve them, including the argus_edge installer row.
    await client.query(
      `revoke argus_brokerage_owner,argus_identity_owner,argus_edge
         from postgres granted by postgres`,
    );
    const baseline = await client.query(
      `select
         pg_catalog.pg_has_role(
           'postgres','argus_brokerage_owner','set'
         ) can_set_brokerage_owner,
         pg_catalog.pg_has_role(
           'postgres','argus_identity_owner','set'
         ) can_set_identity_owner,
         pg_catalog.pg_has_role(
           'postgres','argus_edge','set'
         ) can_set_edge`,
    );
    if (baseline.rows[0]?.can_set_brokerage_owner !== false ||
      baseline.rows[0]?.can_set_identity_owner !== false ||
      baseline.rows[0]?.can_set_edge !== false) {
      throw new Error("postgres unexpectedly retains U5 harness SET authority");
    }
    await client.query(
      `grant argus_brokerage_owner,argus_identity_owner,argus_edge to postgres
         with set true granted by postgres`,
    );
    const memberTransition = await client.query(
      `select
         pg_catalog.pg_has_role(
           'argus_edge','argus_member','set'
         ) edge_can_set_member,
         pg_catalog.pg_has_role(
           'postgres','argus_member','set'
         ) postgres_can_set_member`,
    );
    if (memberTransition.rows[0]?.edge_can_set_member !== true ||
      memberTransition.rows[0]?.postgres_can_set_member !== true) {
      throw new Error("argus_edge cannot supply the existing member SET chain");
    }

    await client.query("set local role argus_brokerage_owner");
    for (const [policy, relation] of brokerageHarnessPolicies) {
      await client.query(`drop policy if exists ${policy} on ${relation}`);
    }
    await client.query(
      `create policy u5_lock_harness_connection_insert
         on argus_brokerage.connections
         for insert to argus_brokerage_owner
         with check (user_id='${userId}'::uuid)`,
    );
    await client.query(
      `create policy u5_lock_harness_connection_delete
         on argus_brokerage.connections
         for delete to argus_brokerage_owner
         using (user_id='${userId}'::uuid)`,
    );
    await client.query(
      `create policy u5_lock_harness_account_insert
         on argus_brokerage.accounts
         for insert to argus_brokerage_owner
         with check (user_id='${userId}'::uuid)`,
    );
    await client.query(
      `create policy u5_lock_harness_credential_insert
         on argus_private.webull_credentials
         for insert to argus_brokerage_owner
         with check (user_id='${userId}'::uuid)`,
    );
    await client.query(
      `create policy u5_lock_harness_command_delete
         on argus_private.provider_commands
         for delete to argus_brokerage_owner
         using (user_id='${userId}'::uuid)`,
    );
    await client.query(
      `create policy u5_lock_harness_attempt_delete
         on argus_private.provider_command_attempts
         for delete to argus_brokerage_owner
         using (user_id='${userId}'::uuid)`,
    );
    await client.query(
      `create policy u5_lock_harness_reconciliation_delete
         on argus_private.reconciliation_records
         for delete to argus_brokerage_owner
         using (user_id='${userId}'::uuid)`,
    );
    await client.query("reset role");
    await client.query("set local role argus_identity_owner");
    for (const [policy, relation] of identityHarnessPolicies) {
      await client.query(`drop policy if exists ${policy} on ${relation}`);
    }
    await client.query(
      `create policy u5_lock_harness_lifecycle_delete
         on argus_app.member_lifecycles
         for delete to argus_identity_owner
         using (identity_subject_id='${userId}'::uuid)`,
    );
    await client.query("commit");
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  }
}

async function removeHarnessAccess(client) {
  await client.query("begin");
  let fixtureRows = -1;
  try {
    await client.query("set local role argus_brokerage_owner");
    const brokerageFixtures = await client.query(
      `select pg_catalog.sum(fixture.count)::bigint fixture_rows
         from (
           select pg_catalog.count(*) count
             from argus_private.provider_command_attempts where user_id=$1
           union all select pg_catalog.count(*)
             from argus_private.reconciliation_records where user_id=$1
           union all select pg_catalog.count(*)
             from argus_private.provider_commands where user_id=$1
           union all select pg_catalog.count(*)
             from argus_private.webull_credentials where user_id=$1
           union all select pg_catalog.count(*)
             from argus_brokerage.accounts where user_id=$1
           union all select pg_catalog.count(*)
             from argus_brokerage.connections where user_id=$1
         ) fixture`,
      [userId],
    );
    fixtureRows = Number(brokerageFixtures.rows[0]?.fixture_rows ?? -1);
    for (const [policy, relation] of brokerageHarnessPolicies) {
      await client.query(`drop policy if exists ${policy} on ${relation}`);
    }
    await client.query("reset role");
    await client.query("set local role argus_identity_owner");
    const lifecycleFixtures = await client.query(
      `select pg_catalog.count(*)::bigint fixture_rows
         from argus_app.member_lifecycles
        where identity_subject_id=$1`,
      [userId],
    );
    fixtureRows += Number(lifecycleFixtures.rows[0]?.fixture_rows ?? -1);
    for (const [policy, relation] of identityHarnessPolicies) {
      await client.query(`drop policy if exists ${policy} on ${relation}`);
    }
    await client.query("reset role");
    const identityFixtures = await client.query(
      `select (
         (select pg_catalog.count(*) from auth.users where id=$1) +
         (select pg_catalog.count(*) from argus_app.members where user_id=$1)
       )::bigint fixture_rows`,
      [userId],
    );
    fixtureRows += Number(identityFixtures.rows[0]?.fixture_rows ?? -1);
    await client.query(
      `revoke argus_brokerage_owner,argus_identity_owner,argus_edge
         from postgres granted by postgres`,
    );
    await client.query("commit");
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  }

  const residue = await client.query(
    `select
       (select pg_catalog.count(*)
          from pg_catalog.pg_policies policy
         where policy.policyname=any($1::name[])) policy_count,
       pg_catalog.pg_has_role(
         'postgres','argus_brokerage_owner','set'
       ) can_set_brokerage_owner,
       pg_catalog.pg_has_role(
         'postgres','argus_identity_owner','set'
       ) can_set_identity_owner,
       pg_catalog.pg_has_role(
         'postgres','argus_edge','set'
       ) can_set_edge,
       (select pg_catalog.count(*)
          from pg_catalog.pg_auth_members membership
          join pg_catalog.pg_roles granted_role
            on granted_role.oid=membership.roleid
          join pg_catalog.pg_roles member_role
            on member_role.oid=membership.member
          join pg_catalog.pg_roles grantor_role
            on grantor_role.oid=membership.grantor
         where member_role.rolname='postgres'
           and granted_role.rolname=any($2::name[])
           and grantor_role.rolname='postgres'
           and (membership.set_option or membership.inherit_option)
       ) postgres_grantor_capability_count`,
    [harnessPolicies.map(([policy]) => policy), harnessRoles],
  );
  if (fixtureRows !== 0 || Number(residue.rows[0]?.policy_count) !== 0 ||
    residue.rows[0]?.can_set_brokerage_owner !== false ||
    residue.rows[0]?.can_set_identity_owner !== false ||
    residue.rows[0]?.can_set_edge !== false ||
    Number(residue.rows[0]?.postgres_grantor_capability_count) !== 0) {
    throw new Error(
      `U5 lock verification cleanup residue: fixtures=${fixtureRows}, ` +
        `policies=${residue.rows[0]?.policy_count}, ` +
        `canSetOwner=${residue.rows[0]?.can_set_brokerage_owner}, ` +
        `canSetIdentity=${residue.rows[0]?.can_set_identity_owner}, ` +
        `canSetEdge=${residue.rows[0]?.can_set_edge}, ` +
        `postgresGrantorCapabilities=` +
        `${residue.rows[0]?.postgres_grantor_capability_count}`,
    );
  }
}

async function cleanupFixture(client) {
  await client.query("begin");
  try {
    await client.query("set local role argus_brokerage_owner");
    await client.query(
      "delete from argus_private.provider_command_attempts where user_id=$1",
      [userId],
    );
    await client.query(
      "delete from argus_private.reconciliation_records where user_id=$1",
      [userId],
    );
    await client.query(
      "delete from argus_private.provider_commands where user_id=$1",
      [userId],
    );
    await client.query(
      "delete from argus_private.webull_credentials where user_id=$1",
      [userId],
    );
    await client.query(
      "delete from argus_brokerage.accounts where user_id=$1",
      [userId],
    );
    await client.query(
      "delete from argus_brokerage.connections where user_id=$1",
      [userId],
    );
    await client.query("reset role");
    // members has two RESTRICT references to member_lifecycles and cascades
    // from auth.users. Delete it explicitly first so the lifecycle owner can
    // remove the fixed lifecycle before the final Auth parent cleanup.
    await client.query("delete from argus_app.members where user_id=$1", [userId]);
    await client.query("set local role argus_identity_owner");
    await client.query(
      "delete from argus_app.member_lifecycles where identity_subject_id=$1",
      [userId],
    );
    await client.query("reset role");
    await client.query("delete from auth.users where id=$1", [userId]);
    await client.query("commit");
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  }
}

async function installMemberContext(client) {
  await client.query("set local role argus_edge");
  await client.query(
    "select argus_private.install_request_context($1,$2,'aal1')",
    [userId, sessionId],
  );
  await client.query("reset role");
  await client.query("set local role argus_member");
}

async function disposeHarness() {
  const client = await pool.connect();
  const failures = [];
  try {
    await cleanupFixture(client);
  } catch (error) {
    failures.push(error);
  }
  try {
    await removeHarnessAccess(client);
  } catch (error) {
    failures.push(error);
  } finally {
    client.release();
    await pool.end();
  }
  if (failures.length > 0) {
    throw new AggregateError(failures, "U5 lock verification cleanup failed");
  }
}

const access = await pool.connect();
let accessFailure;
try {
  await installHarnessAccess(access);
} catch (error) {
  accessFailure = error;
} finally {
  access.release();
}
if (accessFailure !== undefined) {
  await pool.end();
  throw accessFailure;
}

const seed = await pool.connect();
let seedFailure;
try {
  await cleanupFixture(seed);
  await seed.query(
    `insert into auth.users(
       instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
       raw_app_meta_data,raw_user_meta_data,created_at,updated_at
     ) values (
       '00000000-0000-0000-0000-000000000000',$1,'authenticated',
       'authenticated','u5-lock@example.test','',now(),'{}','{}',now(),now()
    )`,
    [userId],
  );
  await seed.query("begin");
  try {
    await seed.query("set local role argus_brokerage_owner");
    await seed.query(
      `insert into argus_brokerage.connections(
         id,user_id,deletion_epoch,status
       ) values ($1,$2,0,'connected')`,
      [connectionId, userId],
    );
    for (const [index, scopedAccountId] of accountIds.entries()) {
      await seed.query(
        `insert into argus_brokerage.accounts(
           id,user_id,deletion_epoch,connection_id,display_label,base_currency,
           status,capability_version,capabilities,fetched_at,expires_at
         ) values ($1,$2,0,$3,$4,'USD','available',1,'[]',now(),
           now()+interval '5 minutes')`,
        [scopedAccountId, userId, connectionId, `Lock proof ${index + 1}`],
      );
    }
    await seed.query(
      `insert into argus_private.webull_credentials(
         connection_id,user_id,deletion_epoch,token_version,key_version,
         access_ciphertext,access_nonce,access_tag,refresh_ciphertext,
         refresh_nonce,refresh_tag,wrapped_data_key,wrapped_key_nonce,
         wrapped_key_tag,associated_data_hash,access_expires_at,
         refresh_expires_at,provider_environment
       ) values (
         $1,$2,0,1,1,$3,$4,$5,$3,$4,$5,$3,$4,$5,$6,
         now()+interval '1 hour',now()+interval '1 day','sandbox'
       )`,
      [
        connectionId,
        userId,
        Buffer.alloc(32, 1),
        Buffer.alloc(12, 2),
        Buffer.alloc(16, 3),
        "a".repeat(64),
      ],
    );
    for (const [index, commandId] of commandIds.entries()) {
      await seed.query(
        `insert into argus_private.provider_commands(
           id,user_id,deletion_epoch,connection_id,account_id,operation,
           client_order_id,idempotency_key,normalized_payload_hash,
           reviewed_payload_hash,capability_version,state,egress_started_at,
           normalized_payload
         ) values (
           $1,$2,0,$3,$4,'place',$5,$6,$7,$8,1,'ambiguous',
           now()-interval '1 minute','{}'::jsonb
         )`,
        [
          commandId,
          userId,
          connectionId,
          accountIds[index],
          `argus_u5_lock_${String(index + 1).padStart(4, "0")}`,
          `u5-lock-idempotency-${String(index + 1).padStart(4, "0")}`,
          "b".repeat(64),
          "c".repeat(64),
        ],
      );
    }
    await seed.query("commit");
  } catch (error) {
    await seed.query("rollback").catch(() => undefined);
    throw error;
  }
} catch (error) {
  await cleanupFixture(seed).catch(() => undefined);
  seedFailure = error;
} finally {
  seed.release();
}
if (seedFailure !== undefined) {
  try {
    await disposeHarness();
  } catch (disposalFailure) {
    throw new AggregateError(
      [seedFailure, disposalFailure],
      "U5 lock verification seed and cleanup failed",
    );
  }
  throw seedFailure;
}

async function claimReconciliation(commandId) {
  const client = await pool.connect();
  const startedAt = performance.now();
  try {
    await client.query("begin");
    await client.query("set local lock_timeout='3s'");
    await client.query("set local role argus_brokerage_owner");
    const claim = await client.query(
      `select argus_private.claim_brokerage_reconciliation_attempt(
         $1,$2,0,clock_timestamp()
       ) outcome`,
      [commandId, userId],
    );
    if (claim.rows[0]?.outcome !== "claimed") {
      throw new Error(`unexpected reconciliation outcome: ${claim.rows[0]?.outcome}`);
    }
    await client.query("commit");
    return performance.now() - startedAt;
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
}

let reconciliationP95;
let guardPaths;
try {
  const reconciliationDurations = await Promise.all(
    commandIds.map((commandId) => claimReconciliation(commandId)),
  );
  const sortedDurations = reconciliationDurations.toSorted((left, right) =>
    left - right
  );
  reconciliationP95 =
    sortedDurations[Math.ceil(sortedDurations.length * 0.95) - 1];
  if (reconciliationP95 > 150) {
    throw new Error(
      `16-way reconciliation p95 ${reconciliationP95.toFixed(3)} ms exceeds 150 ms`,
    );
  }

  guardPaths = await Promise.all([
    exerciseScopeGuard(
      "token-refresh",
      "select argus_private.lock_brokerage_connection_scope($1,null) acquired",
      [connectionId],
    ),
    exerciseScopeGuard(
      "projection-refresh",
      "select argus_private.lock_brokerage_connection_scope($1,$2) acquired",
      [connectionId, accountId],
    ),
    exerciseScopeGuard(
      "command-recovery",
      "select argus_private.lock_brokerage_command_scope($1) acquired",
      [commandIds[0]],
    ),
  ]);
} catch (error) {
  try {
    await disposeHarness();
  } catch (disposalFailure) {
    throw new AggregateError(
      [error, disposalFailure],
      "U5 reconciliation proof and cleanup failed",
    );
  }
  throw error;
}

async function exerciseScopeGuard(label, sql, parameters) {
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query("set local lock_timeout='3s'");
    await client.query("set local role argus_brokerage_owner");
    const result = await client.query(sql, parameters);
    if (result.rows.length !== 1 || !Object.values(result.rows[0]).includes(true)) {
      throw new Error(`${label} did not acquire its scoped guard`);
    }
    await new Promise((resolve) => setTimeout(resolve, 75));
    await client.query("commit");
    return label;
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
}

const appendClient = await pool.connect();
const fenceClient = await pool.connect();
try {
  await appendClient.query("begin");
  await installMemberContext(appendClient);
  const generation = await appendClient.query(
    `select result_list_generation
       from argus_private.begin_brokerage_order_list_ingestion($1,$2,0)`,
    [accountId, connectionId],
  );
  if (generation.rows[0]?.result_list_generation !== "1") {
    throw new Error("failed to acquire scoped order-list generation");
  }

  await fenceClient.query("begin");
  await installMemberContext(fenceClient);
  let fenceFinished = false;
  const fence = fenceClient.query(
    "select argus_private.require_brokerage_reauthorization_scoped($1)",
    [connectionId],
  ).then((result) => {
    fenceFinished = true;
    return result;
  });
  await new Promise((resolve) => setTimeout(resolve, 250));
  if (fenceFinished) {
    throw new Error("connection fence bypassed the list-ingestion scope lock");
  }

  await appendClient.query(
    `select argus_private.complete_brokerage_order_list_ingestion(
       $1,$2,0,1,'[]'::jsonb,now(),now(),now()+interval '5 minutes',
       'available',null
     )`,
    [accountId, connectionId],
  );
  await appendClient.query("commit");
  const fenced = await fence;
  if (fenced.rows[0]?.require_brokerage_reauthorization_scoped !== true) {
    throw new Error("connection fence did not apply after serialization");
  }
  await fenceClient.query("commit");

  const afterFence = await pool.connect();
  try {
    await afterFence.query("begin");
    await installMemberContext(afterFence);
    let rejected = false;
    try {
      await afterFence.query(
        `select argus_private.complete_brokerage_order_list_ingestion(
           $1,$2,0,2,'[]'::jsonb,now(),now(),now()+interval '5 minutes',
           'available',null
         )`,
        [accountId, connectionId],
      );
    } catch (error) {
      rejected = error instanceof Error &&
        error.message.includes("order_list_ingestion_fenced");
    }
    await afterFence.query("rollback");
    if (!rejected) throw new Error("post-fence list write was not rejected");
  } finally {
    afterFence.release();
  }
  console.log(
    `U5 lock proof passed: 16-way reconciliation p95=${reconciliationP95.toFixed(3)} ms; ` +
      `${guardPaths.join(", ")} serialized without deadlock; ` +
      "list write serialized before reauthorization; post-fence write rejected",
  );
} catch (error) {
  await appendClient.query("rollback").catch(() => undefined);
  await fenceClient.query("rollback").catch(() => undefined);
  throw error;
} finally {
  appendClient.release();
  fenceClient.release();
  await disposeHarness();
}
