import {createSupabaseAccessTokenVerifier} from "../_shared/auth.ts";
import {createSupabaseDatabasePool} from "../_shared/database.ts";
import {requiredEnvironment} from "../_shared/environment.ts";
import {rewriteSupabaseFunctionRequest} from "../_shared/http.ts";
import {createPostgresRateLimitPort} from "../_shared/rate-limit.ts";
import {createStrategyApp} from "../../../ritual-investing-api/src/domains/strategy-lab/app.ts";
import {productionStrategyOrigins} from "../../../ritual-investing-api/src/domains/strategy-lab/origins.ts";
import {createStrategyRepository} from "../../../ritual-investing-api/src/domains/strategy-lab/repository.ts";
import {createSupervisorProvider} from "../../../ritual-investing-api/src/domains/strategy-lab/supervisor.ts";
const pool=createSupabaseDatabasePool(requiredEnvironment("EDGE_RUNTIME_DATABASE_URL"));
const origins=productionStrategyOrigins(requiredEnvironment("STRATEGY_CONSUMER_ORIGINS"));
const configured=["STRATEGY_SUPERVISOR_BASE_URL","STRATEGY_SUPERVISOR_API_KEY","STRATEGY_SUPERVISOR_MODEL"].map(name=>Deno.env.get(name)?.trim()??"");
// No default model, implicit provider, or paid fallback; missing configuration
// disables only explanations, not the deterministic pause controls.
const supervisor=(()=>{if(!configured.every(Boolean))return undefined;try{return createSupervisorProvider({baseUrl:configured[0]!,apiKey:configured[1]!,model:configured[2]!});}catch{return undefined;}})();
const app=createStrategyApp({repository:createStrategyRepository(pool),verifyAccessToken:createSupabaseAccessTokenVerifier({supabaseUrl:requiredEnvironment("SUPABASE_URL")}),origins,rateLimit:createPostgresRateLimitPort(pool),supervisor});
Deno.serve(request=>app.fetch(rewriteSupabaseFunctionRequest(request,"strategy-api")));
