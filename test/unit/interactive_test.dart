@Timeout(Duration(seconds: 400))

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'dart:convert';

import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  String anchorToml = '''
      # Sample stellar.toml
      VERSION="2.0.0"
      
      NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
      WEB_AUTH_ENDPOINT="https://api.anchor.org/auth"
      TRANSFER_SERVER_SEP0024="http://api.stellar.org/transfer-sep24/"
      SIGNING_KEY="GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
      
      [[CURRENCIES]]
      code="USDC"
      issuer="GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
      display_decimals=2
      
      [[CURRENCIES]]
      code="ETH"
      issuer="GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U"
      display_decimals=7
     ''';

  const anchorDomain = "place.anchor.com";
  const serviceAddress = "http://api.stellar.org/transfer-sep24/";
  const jwtToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0";

  String requestInfo() {
    return "{  \"deposit\": {    \"USDC\": {      \"enabled\": true,      \"fee_fixed\": 5,      \"fee_percent\": 1,      \"min_amount\": 0.1,      \"max_amount\": 1000    },    \"ETH\": {      \"enabled\": true,      \"fee_fixed\": 0.002,      \"fee_percent\": 0    },    \"native\": {      \"enabled\": true,      \"fee_fixed\": 0.00001,      \"fee_percent\": 0    }  },  \"withdraw\": {    \"USDC\": {      \"enabled\": true,      \"fee_minimum\": 5,      \"fee_percent\": 0.5,      \"min_amount\": 0.1,      \"max_amount\": 1000    },    \"ETH\": {      \"enabled\": false    },    \"native\": {      \"enabled\": true    }  },  \"fee\": {    \"enabled\": false  },  \"features\": {    \"account_creation\": true,    \"claimable_balances\": true  }}";
  }

  String requestInteractive() {
    return "{  \"type\": \"completed\",  \"url\": \"https://api.example.com/kycflow?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI\",  \"id\": \"82fhs729f63dh0v4\"}";
  }

  String requestTransactions() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"completed_at\": \"2017-03-20T17:09:58Z\",      \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"completed_at\": \"2017-03-20T17:09:58Z\",      \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}";
  }

  String requestTransaction() {
    return "{  \"transaction\": {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"completed_at\": \"2017-03-20T17:09:58Z\",      \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }}";
  }

  String requestPendingTransaction() {
    return "{  \"transaction\": {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"pending_external\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }}";
  }

  String requestEmptyTransactions() {
    return "{  \"transactions\": []}";
  }

  String requestPendingTransactions1() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}";
  }

  String requestPendingTransactions2() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}";
  }

  String requestPendingTransactions3() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}";
  }

  String requestPendingTransactions4() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"pending_anchor\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}";
  }

  String requestPendingTransactionsCompleted() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\",      \"claimable_balance_id\": null    },    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523523\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1941491\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",       \"updated_at\": \"2017-03-20T17:09:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"92fhs729f63dh0v3\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"updated_at\": \"2017-03-20T17:05:58Z\",      \"more_info_url\": \"https://youranchor.com/tx/242523526\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1947101\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"1937103\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    }  ]}";
  }

  test('test info', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    AnchorServiceInfo serviceInfo = await anchor.sep24().getServiceInfo();
    assert(serviceInfo.deposit.length == 3);
    AnchorServiceAsset depositAssetUSDC = serviceInfo.deposit["USDC"]!;
    assert(depositAssetUSDC.enabled);
    assert(depositAssetUSDC.feeFixed == 5.0);
    assert(depositAssetUSDC.feePercent == 1.0);
    assert(depositAssetUSDC.feeMinimum == null);
    assert(depositAssetUSDC.minAmount == 0.1);
    assert(depositAssetUSDC.maxAmount == 1000.0);
    AnchorServiceAsset depositAssetETH = serviceInfo.deposit["ETH"]!;
    assert(depositAssetETH.enabled);
    assert(depositAssetETH.feeFixed == 0.002);
    assert(depositAssetETH.feePercent == 0.0);
    assert(depositAssetETH.feeMinimum == null);
    assert(depositAssetETH.minAmount == null);
    assert(depositAssetETH.maxAmount == null);
    AnchorServiceAsset depositAssetNative = serviceInfo.deposit["native"]!;
    assert(depositAssetNative.enabled);
    assert(depositAssetNative.feeFixed == 0.00001);
    assert(depositAssetNative.feePercent == 0.0);
    assert(depositAssetNative.feeMinimum == null);
    assert(depositAssetNative.minAmount == null);
    assert(depositAssetNative.maxAmount == null);

    AnchorServiceAsset withdrawAssetUSDC = serviceInfo.withdraw["USDC"]!;
    assert(withdrawAssetUSDC.enabled);
    assert(withdrawAssetUSDC.feeMinimum == 5.0);
    assert(withdrawAssetUSDC.feePercent == 0.5);
    assert(withdrawAssetUSDC.minAmount == 0.1);
    assert(withdrawAssetUSDC.maxAmount == 1000.0);
    assert(withdrawAssetUSDC.feeFixed == null);
    AnchorServiceAsset withdrawAssetETH = serviceInfo.withdraw["ETH"]!;
    assert(!withdrawAssetETH.enabled);
    AnchorServiceAsset withdrawAssetNative = serviceInfo.withdraw["native"]!;
    assert(withdrawAssetNative.enabled);
    assert(!serviceInfo.fee.enabled);
    assert(serviceInfo.features!.accountCreation);
    assert(serviceInfo.features!.claimableBalances);
  });

  test('test deposit', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }
      String authHeader = request.headers["Authorization"]!;
      String contentType = request.headers["content-type"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "POST" &&
          request.url.toString().contains("transactions/deposit/interactive") &&
          authHeader.contains(jwtToken) &&
          contentType.startsWith("multipart/form-data;")) {
        return http.Response(requestInteractive(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    Sep24 sep24 = anchor.sep24();
    TomlInfo info = await anchor.sep1();
    StellarAssetId assetId =
        info.currencies!.firstWhere((c) => c.code == "USDC").assetId;
    AuthToken token = AuthToken(jwtToken);
    InteractiveFlowResponse response = await sep24.deposit(assetId, token);
    assert("82fhs729f63dh0v4" == response.id);
    assert("completed" == response.type);
    assert(
        "https://api.example.com/kycflow?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI" ==
            response.url);
  });

  test('test withdraw', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }
      String authHeader = request.headers["Authorization"]!;
      String contentType = request.headers["content-type"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "POST" &&
          request.url
              .toString()
              .contains("transactions/withdraw/interactive") &&
          authHeader.contains(jwtToken) &&
          contentType.startsWith("multipart/form-data;")) {
        return http.Response(requestInteractive(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    Sep24 sep24 = anchor.sep24();
    TomlInfo info = await anchor.sep1();
    StellarAssetId assetId =
        info.currencies!.firstWhere((c) => c.code == "USDC").assetId;
    AuthToken token = AuthToken(jwtToken);
    InteractiveFlowResponse response = await sep24.withdraw(assetId, token);
    assert("82fhs729f63dh0v4" == response.id);
    assert("completed" == response.type);
    assert(
        "https://api.example.com/kycflow?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI" ==
            response.url);
  });

  test('test multiple transactions', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("transactions") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestTransactions(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    TomlInfo info = await anchor.sep1();
    StellarAssetId assetId =
        info.currencies!.firstWhere((c) => c.code == "ETH").assetId;
    AuthToken token = AuthToken(jwtToken);
    Sep24 sep24 = anchor.sep24();
    List<AnchorTransaction> transactions =
        await sep24.getHistory(assetId, token);

    assert(transactions.length == 4);

    AnchorTransaction transaction = transactions.first;
    assert("82fhs729f63dh0v4" == transaction.id);
    assert(transaction is DepositTransaction);
    assert(TransactionStatus.pendingExternal == transaction.status);
    DepositTransaction depositTx = transaction as DepositTransaction;
    assert("2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093" ==
        depositTx.externalTransactionId);
    assert("https://youranchor.com/tx/242523523" == transaction.moreInfoUrl);
    assert("18.34" == depositTx.amountIn);
    assert("18.24" == depositTx.amountOut);
    assert("0.1" == depositTx.amountFee);
    assert(DateTime.parse("2017-03-20T17:05:32Z") == depositTx.startedAt);
    assert(null == depositTx.claimableBalanceId);

    transaction = transactions[1];
    assert("82fhs729f63dh0v4" == transaction.id);
    assert(TransactionStatus.completed == transaction.status);
    assert(transaction is WithdrawalTransaction);
    WithdrawalTransaction withdrawalTx = transaction as WithdrawalTransaction;
    assert("510" == withdrawalTx.amountIn);
    assert("490" == withdrawalTx.amountOut);
    assert("5" == withdrawalTx.amountFee);
    assert(DateTime.parse("2017-03-20T17:00:02Z") == withdrawalTx.startedAt);
    assert(DateTime.parse("2017-03-20T17:09:58Z") == withdrawalTx.completedAt);
    assert(DateTime.parse("2017-03-20T17:09:58Z") == withdrawalTx.updatedAt);
    assert("https://youranchor.com/tx/242523523" == withdrawalTx.moreInfoUrl);
    assert("17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a" ==
        withdrawalTx.stellarTransactionId);
    assert("1941491" == withdrawalTx.externalTransactionId);
    assert("GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL" ==
        withdrawalTx.withdrawAnchorAccount);
    assert("186384" == withdrawalTx.withdrawalMemo);
    assert("id" == withdrawalTx.withdrawalMemoType);
    assert("10" == withdrawalTx.refunds!.amountRefunded);
    assert("5" == withdrawalTx.refunds!.amountFee);
    List<Payment> refundPayments = withdrawalTx.refunds!.payments;
    Payment refundPayment = refundPayments.first;
    assert("b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020" ==
        refundPayment.id);
    assert("stellar" == refundPayment.idType);
    assert("10" == refundPayment.amount);
    assert("5" == refundPayment.fee);
  });

  test('test single transaction', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("transaction") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestTransaction(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    AuthToken token = AuthToken(jwtToken);
    Sep24 sep24 = anchor.sep24();
    AnchorTransaction transaction = await sep24.getTransaction(
        "82fhs729f63dh0v4",
        token);

    assert("82fhs729f63dh0v4" == transaction.id);
    assert(TransactionStatus.completed == transaction.status);
    assert(transaction is WithdrawalTransaction);
    WithdrawalTransaction withdrawalTx = transaction as WithdrawalTransaction;

    assert("510" == withdrawalTx.amountIn);
    assert("490" == withdrawalTx.amountOut);
    assert("5" == withdrawalTx.amountFee);
    assert(DateTime.parse("2017-03-20T17:00:02Z") == withdrawalTx.startedAt);
    assert(DateTime.parse("2017-03-20T17:09:58Z") == withdrawalTx.completedAt);
    assert(DateTime.parse("2017-03-20T17:09:58Z") == withdrawalTx.updatedAt);
    assert("https://youranchor.com/tx/242523523" == withdrawalTx.moreInfoUrl);
    assert("17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a" ==
        withdrawalTx.stellarTransactionId);
    assert("1941491" == withdrawalTx.externalTransactionId);
    assert("GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL" ==
        withdrawalTx.withdrawAnchorAccount);
    assert("186384" == withdrawalTx.withdrawalMemo);
    assert("id" == withdrawalTx.withdrawalMemoType);
    assert("10" == withdrawalTx.refunds!.amountRefunded);
    assert("5" == withdrawalTx.refunds!.amountFee);
    List<Payment> refundPayments = transaction.refunds!.payments;
    assert(refundPayments.length == 1);
    Payment refundPayment = refundPayments.first;
    assert("b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020" ==
        refundPayment.id);
    assert("stellar" == refundPayment.idType);
    assert("10" == refundPayment.amount);
    assert("5" == refundPayment.fee);
  });

  test('test transaction by', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("transaction") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestTransaction(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    AuthToken token = AuthToken(jwtToken);
    Sep24 sep24 = anchor.sep24();
    AnchorTransaction transaction = await sep24.getTransactionBy(token,
        stellarTransactionId: "17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a");

    assert("82fhs729f63dh0v4" == transaction.id);
  });

  test('test empty transactions result', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("transactions") &&
          authHeader.contains(jwtToken)) {
        return http.Response(requestEmptyTransactions(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    TomlInfo info = await anchor.sep1();
    StellarAssetId assetId =
        info.currencies!.firstWhere((c) => c.code == "ETH").assetId;
    AuthToken token = AuthToken(jwtToken);
    Sep24 sep24 = anchor.sep24();
    List<AnchorTransaction> transactions =
        await sep24.getHistory(assetId, token);
    assert(transactions.isEmpty);
  });

  test('test not found transaction', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }
      final mapJson = {'error': "not found"};
      return http.Response(json.encode(mapJson), 404);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    AuthToken token = AuthToken(jwtToken);
    Sep24 sep24 = anchor.sep24();

    bool thrown = false;
    try {
      await sep24.getTransaction(
          "17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a",
          token);
    } on AnchorTransactionNotFoundException catch (e) {
      if (e.cause is flutter_sdk.SEP24TransactionNotFoundException) {
        thrown = true;
      }
    }
    assert(thrown);
  });

  test('test watcher one transaction', () async {
    int counter = 0;
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("transaction") &&
          authHeader.contains(jwtToken)) {
        print("Count: $counter");
        if (counter < 3) {
          counter++;
          return http.Response(requestPendingTransaction(), 200);
        } else {
          return http.Response(requestTransaction(), 200);
        }
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    AuthToken token = AuthToken(jwtToken);
    Sep24 sep24 = anchor.sep24();
    Watcher watcher = sep24.watcher();
    WatcherResult result = watcher.watchOneTransaction(token,
        "17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a");

    bool completed = false;
    bool done = false;
    bool exceptionHandlerExit = false;
    bool streamControllerClosed = false;
    bool error = false;
    result.controller.stream.listen(
      (event) {
        if (event is StatusChange) {
          if (counter < 3) {
            assert(TransactionStatus.pendingExternal == event.status);
          } else {
            assert(TransactionStatus.completed == event.status);
            completed = true;
          }
        } else if (event is ExceptionHandlerExit) {
          exceptionHandlerExit = true;
        } else if (event is StreamControllerClosed) {
          streamControllerClosed = true;
        }
      },
      onDone: () {
        print("Done");
        done = true;
      },
      onError: (error) {
        print('Error: $error');
        error = true;
      },
    );
    await Future.delayed(const Duration(seconds: 25), () {});
    assert(completed);
    assert(done);
    assert(exceptionHandlerExit);
    assert(streamControllerClosed);
    assert(!error);
  });

  test('test watcher on asset', () async {
    int counter = 0;
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("info")) {
        return http.Response(requestInfo(), 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("transactions") &&
          authHeader.contains(jwtToken)) {
        counter++;
        print("Count: $counter");
        if (counter == 1) {
          return http.Response(requestPendingTransactions1(), 200);
        }
        if (counter == 2) {
          return http.Response(requestPendingTransactions2(), 200);
        }
        if (counter == 3) {
          return http.Response(requestPendingTransactions3(), 200);
        }
        if (counter == 4) {
          return http.Response(requestPendingTransactions4(), 200);
        } else {
          return http.Response(requestPendingTransactionsCompleted(), 200);
        }
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    AuthToken token = AuthToken(jwtToken);
    Sep24 sep24 = anchor.sep24();
    Watcher watcher = sep24.watcher();
    WatcherResult result = watcher.watchAsset(
        token,
        IssuedAssetId(
            code: "USDC",
            issuer:
                "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"));

    bool completed = false;
    bool done = false;
    bool exceptionHandlerExit = false;
    bool streamControllerClosed = false;
    bool error = false;
    result.controller.stream.listen(
      (event) {
        if (event is StatusChange) {
          if (counter == 1) {
            assert(TransactionStatus.pendingAnchor == event.status);
          } else {
            assert(TransactionStatus.completed == event.status);
            if (counter == 5) {
              completed = true;
            }
          }
        } else if (event is ExceptionHandlerExit) {
          exceptionHandlerExit = true;
        } else if (event is StreamControllerClosed) {
          streamControllerClosed = true;
        }
      },
      onDone: () {
        print("Done");
        done = true;
      },
      onError: (error) {
        print('Error: $error');
        error = true;
      },
    );
    await Future.delayed(const Duration(seconds: 30), () {});
    assert(completed);
    assert(done);
    assert(exceptionHandlerExit);
    assert(streamControllerClosed);
    assert(!error);
  });
}
