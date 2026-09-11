# Broker application drafts

Prepared 2026-09-05. **Local drafts only; nothing has been submitted or sent.**

- Applicant-supplied name: **Leo**. This is not a verified legal entity name or
  evidence of incorporation.
- Contact email: **gh2722@columbia.edu**.
- Proposed scope: US users, initially US stocks, with users reviewing and
  confirming individual orders in their own brokerage accounts. Accounts and
  assets remain at the brokers.
- Research is read-only and separate from orders. Research output does not
  authorize a trade; automatic execution remains disabled.
- Current stage: application setup and local contract/sanitized-fixture tests.
  No live broker connection or approved hosted sandbox integration is claimed.

## IBKR email draft

**To:** api-solutions@interactivebrokers.com  
**Subject:** Leo — proposed US third-party Web API integration

Hello IBKR API Solutions team,

I am applying under the name Leo; my contact email is gh2722@columbia.edu.
Our legal applicant/entity details are still being confirmed.

We are developing a platform for US users to connect their existing IBKR
accounts, view balances and positions, and review and explicitly confirm manual
US stock orders. Customer accounts and assets would remain with IBKR. Our
market-research features are read-only and separate from order submission;
there is no unattended or discretionary execution in the proposed scope.

We are at the integration setup stage. Could you confirm third-party applicant
eligibility, required legal/business information, the current authorization
protocol, and onboarding for paper-account testing? Please also identify any
agreements needed for market-data display and analysis in this offering.

Our deployed callback URL and public product URL are pending verification.
We will supply the exact URLs and a workflow demonstration when ready.

Thank you,
Leo
gh2722@columbia.edu

[Official IBKR third-party onboarding requirements](https://www.interactivebrokers.com/docs/web-api/getting-started)

## Webull Connect application draft

| Form item | Draft response |
| --- | --- |
| Requested product | Webull Connect API for existing customer accounts |
| Applicant/company name | Leo — applicant-supplied name; legal name and entity type pending verification |
| Contact email | gh2722@columbia.edu |
| Users and initial instruments | US users; US stocks |
| Intended services | User-authorized account, balance and position access; user-reviewed and confirmed manual orders |
| Research relationship | Read-only research; a separate user action creates and confirms order intent |
| Custody | Accounts and customer assets remain with Webull |
| Current stage | Local integration groundwork; requesting sandbox onboarding |
| OAuth redirect URL | Pending deployed callback endpoint and exact URL verification |
| Public website/product URL | Pending verification |
| Legal status, registrations and fees | Pending applicant confirmation; no exemption or registration status asserted |

Submit through the application form linked from the official page after the
missing applicant fields are resolved. Webull issues integration details after
approval; production follows approved sandbox testing. Resolve the additional
protocol questions in [the local Webull contract](webull-connect-contract.md).
[Official Webull Connect application process](https://developer.webull.com/apis/docs/connect-api/about-connect-api/)

## moomoo registration prerequisites

The official guide documents dynamic OAuth client registration and recommends
OAuth 2.1 with PKCE for third-party apps. It does not state a partner-approval
prerequisite on this setup page.

- Confirm the app identity and eligibility for the intended US account types.
- Deploy and verify the exact callback URL before registering it.
- Proposed public-client fields: `client_name` = `Leo`; `redirect_uris` = the
  verified callback; `token_endpoint_auth_method` = `none`; `grant_types` =
  `authorization_code` and `refresh_token`; `response_types` = `code`.
- Registration endpoint: `POST https://webapi.moomoo.com/oauth2/register`.
  No request has been made and no client ID has been issued for this work.
- Finish secure callback/token custody, user authorization and account/market
  entitlement checks, then validate simulated account behavior before any
  live manual-order integration. Confirm commercial data-use rights separately.

[Official moomoo OAuth setup](https://open.moomoo.com/api/overview/getting-started)

## Information still needed before submission

Legal applicant name/type and incorporation status; authorized business contact
details if different; verified product and callback URLs; business/fee model;
and any registrations or applicable regulatory assessment requested by brokers.
API availability does not establish a regulatory exemption. See the
[current implementation status](us-broker-integration.md) for technical blockers.
