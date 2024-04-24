@Timeout(Duration(seconds: 400))

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'dart:convert';

import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  const anchorDomain = "place.anchor.com";
  const serviceAddress = "http://api.stellar.org/transfer/";

  String anchorToml = '''
      # Sample stellar.toml
      VERSION="2.0.0"
      
      NETWORK_PASSPHRASE="Test SDF Network ; September 2015"
      WEB_AUTH_ENDPOINT="https://api.anchor.org/auth"
      TRANSFER_SERVER="http://api.stellar.org/transfer/"
      SIGNING_KEY="GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
      
      [[CURRENCIES]]
      code="USD"
      issuer="GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
      display_decimals=2
      
      [[CURRENCIES]]
      code="ETH"
      issuer="GAOO3LWBC4XF6VWRP5ESJ6IBHAISVJMSBTALHOQM2EZG7Q477UWA6L7U"
      display_decimals=7
     ''';

  const jwtToken =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJHQTZVSVhYUEVXWUZJTE5VSVdBQzM3WTRRUEVaTVFWREpIREtWV0ZaSjJLQ1dVQklVNUlYWk5EQSIsImp0aSI6IjE0NGQzNjdiY2IwZTcyY2FiZmRiZGU2MGVhZTBhZDczM2NjNjVkMmE2NTg3MDgzZGFiM2Q2MTZmODg1MTkwMjQiLCJpc3MiOiJodHRwczovL2ZsYXBweS1iaXJkLWRhcHAuZmlyZWJhc2VhcHAuY29tLyIsImlhdCI6MTUzNDI1Nzk5NCwiZXhwIjoxNTM0MzQ0Mzk0fQ.8nbB83Z6vGBgC1X9r3N6oQCFTBzDiITAfCJasRft0z0";
  const accountId = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP";

  String requestInfo() {
    return "{  \"deposit\": {    \"USD\": {      \"enabled\": true,      \"authentication_required\": true,      \"min_amount\": 0.1,      \"max_amount\": 1000,      \"fields\": {        \"email_address\" : {          \"description\": \"your email address for transaction status updates\",          \"optional\": true        },        \"amount\" : {          \"description\": \"amount in USD that you plan to deposit\"        },        \"country_code\": {          \"description\": \"The ISO 3166-1 alpha-3 code of the user's current address\",          \"choices\": [\"USA\", \"PRI\"]        },        \"type\" : {          \"description\": \"type of deposit to make\",          \"choices\": [\"SEPA\", \"SWIFT\", \"cash\"]        }      }    },    \"ETH\": {      \"enabled\": true,      \"authentication_required\": false    }  },  \"deposit-exchange\": {    \"USD\": {      \"authentication_required\": true,      \"fields\": {        \"email_address\" : {          \"description\": \"your email address for transaction status updates\",          \"optional\": true        },        \"amount\" : {          \"description\": \"amount in USD that you plan to deposit\"        },        \"country_code\": {          \"description\": \"The ISO 3166-1 alpha-3 code of the user's current address\",          \"choices\": [\"USA\", \"PRI\"]        },        \"type\" : {          \"description\": \"type of deposit to make\",          \"choices\": [\"SEPA\", \"SWIFT\", \"cash\"]        }      }    }  },  \"withdraw\": {    \"USD\": {      \"enabled\": true,      \"authentication_required\": true,      \"min_amount\": 0.1,      \"max_amount\": 1000,      \"types\": {        \"bank_account\": {          \"fields\": {              \"dest\": {\"description\": \"your bank account number\" },              \"dest_extra\": { \"description\": \"your routing number\" },              \"bank_branch\": { \"description\": \"address of your bank branch\" },              \"phone_number\": { \"description\": \"your phone number in case there's an issue\" },              \"country_code\": {                \"description\": \"The ISO 3166-1 alpha-3 code of the user's current address\",                \"choices\": [\"USA\", \"PRI\"]              }          }        },        \"cash\": {          \"fields\": {            \"dest\": {              \"description\": \"your email address. Your cashout PIN will be sent here. If not provided, your account's default email will be used\",              \"optional\": true            }          }        }      }    },    \"ETH\": {      \"enabled\": false    }  },  \"withdraw-exchange\": {    \"USD\": {      \"authentication_required\": true,      \"min_amount\": 0.1,      \"max_amount\": 1000,      \"types\": {        \"bank_account\": {          \"fields\": {              \"dest\": {\"description\": \"your bank account number\" },              \"dest_extra\": { \"description\": \"your routing number\" },              \"bank_branch\": { \"description\": \"address of your bank branch\" },              \"phone_number\": { \"description\": \"your phone number in case there's an issue\" },              \"country_code\": {                \"description\": \"The ISO 3166-1 alpha-3 code of the user's current address\",                \"choices\": [\"USA\", \"PRI\"]              }          }        },        \"cash\": {          \"fields\": {            \"dest\": {              \"description\": \"your email address. Your cashout PIN will be sent here. If not provided, your account's default email will be used\",              \"optional\": true            }          }        }      }    }  },  \"fee\": {    \"enabled\": false,    \"description\": \"Fees vary from 3 to 7 percent based on the the assets transacted and method by which funds are delivered to or collected by the anchor.\"  },  \"transactions\": {    \"enabled\": true,    \"authentication_required\": true  },  \"transaction\": {    \"enabled\": false,    \"authentication_required\": true  },  \"features\": {    \"account_creation\": true,    \"claimable_balances\": true  }}";
  }

  String requestBankDeposit() {
    return "{  \"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\",  \"instructions\": {    \"organization.bank_number\": {      \"value\": \"121122676\",      \"description\": \"US bank routing number\"    },    \"organization.bank_account_number\": {      \"value\": \"13719713158835300\",      \"description\": \"US bank account number\"    }  },  \"how\": \"Make a payment to Bank: 121122676 Account: 13719713158835300\"}";
  }

  String requestBTCDeposit() {
    return "{  \"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\",  \"instructions\": {    \"organization.crypto_address\": {      \"value\": \"1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB\",      \"description\": \"Bitcoin address\"    }  },  \"how\": \"Make a payment to Bitcoin address 1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB\",  \"fee_fixed\": 0.0002}";
  }

  String requestRippleDeposit() {
    return "{  \"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\",  \"instructions\": {    \"organization.crypto_address\": {      \"value\": \"rNXEkKCxvfLcM1h4HJkaj2FtmYuAWrHGbf\",      \"description\": \"Ripple address\"    },    \"organization.crypto_memo\": {      \"value\": \"88\",      \"description\": \"Ripple tag\"    }  },  \"how\": \"Make a payment to Ripple address rNXEkKCxvfLcM1h4HJkaj2FtmYuAWrHGbf with tag 88\",  \"eta\": 60,  \"fee_percent\": 0.1,  \"extra_info\": {    \"message\": \"You must include the tag. If the amount is more than 1000 XRP, deposit will take 24h to complete.\"  }}";
  }

  String requestMXNDeposit() {
    return "{  \"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\",  \"instructions\": {    \"organization.clabe_number\": {      \"value\": \"646180111803859359\",      \"description\": \"CLABE number\"    }  },  \"how\": \"Make a payment to Bank: STP Account: 646180111803859359\",  \"eta\": 1800}";
  }

  String requestWithdrawSuccess() {
    return "{\"account_id\": \"GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ\",\"memo_type\": \"id\",\"memo\": \"123\",\"id\": \"9421871e-0623-4356-b7b5-5996da122f3e\"}";
  }

  String requestCustomerInformationNeeded() {
    return "{\"type\": \"non_interactive_customer_info_needed\",\"fields\" : [\"family_name\", \"given_name\", \"address\", \"tax_id\"]}";
  }

  String requestCustomerInformationStatus() {
    return "{\"type\": \"customer_info_status\",\"status\": \"denied\",\"more_info_url\": \"https://api.example.com/kycstatus?account=GACW7NONV43MZIFHCOKCQJAKSJSISSICFVUJ2C6EZIW5773OU3HD64VI\"}";
  }

  String requestTransactions() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },    {      \"id\": \"52fys79f63dh3v2\",      \"kind\": \"deposit-exchange\",      \"status\": \"pending_anchor\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"500\",      \"amount_in_asset\": \"iso4217:BRL\",      \"amount_out\": \"100\",      \"amount_out_asset\": \"stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN\",      \"amount_fee\": \"0.1\",      \"amount_fee_asset\": \"iso4217:BRL\",      \"started_at\": \"2021-06-11T17:05:32Z\"    },    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"withdrawal\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"completed_at\": \"2017-03-20T17:09:58Z\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1238234\",      \"withdraw_anchor_account\": \"GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL\",      \"withdraw_memo\": \"186384\",      \"withdraw_memo_type\": \"id\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020\",            \"id_type\": \"stellar\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"72fhs729f63dh0v1\",      \"kind\": \"deposit\",      \"status\": \"completed\",      \"amount_in\": \"510\",      \"amount_out\": \"490\",      \"amount_fee\": \"5\",      \"started_at\": \"2017-03-20T17:00:02Z\",      \"completed_at\": \"2017-03-20T17:09:58Z\",      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"external_transaction_id\": \"1238234\",      \"from\": \"AJ3845SAD\",      \"to\": \"GBITQ4YAFKD2372TNAMNHQ4JV5VS3BYKRK4QQR6FOLAR7XAHC3RVGVVJ\",      \"refunds\": {        \"amount_refunded\": \"10\",        \"amount_fee\": \"5\",        \"payments\": [          {            \"id\": \"104201\",            \"id_type\": \"external\",            \"amount\": \"10\",            \"fee\": \"5\"          }        ]      }    },    {      \"id\": \"52fys79f63dh3v1\",      \"kind\": \"withdrawal\",      \"status\": \"pending_transaction_info_update\",      \"amount_in\": \"750.00\",      \"amount_out\": null,      \"amount_fee\": null,      \"started_at\": \"2017-03-20T17:00:02Z\",      \"required_info_message\": \"We were unable to send funds to the provided bank account. Bank error: 'Account does not exist'. Please provide the correct bank account address.\",      \"required_info_updates\": {        \"transaction\": {          \"dest\": {\"description\": \"your bank account number\" },          \"dest_extra\": { \"description\": \"your routing number\" }        }      }    },    {      \"id\": \"52fys79f63dh3v2\",      \"kind\": \"withdrawal-exchange\",      \"status\": \"pending_anchor\",      \"status_eta\": 3600,      \"stellar_transaction_id\": \"17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a\",      \"amount_in\": \"100\",      \"amount_in_asset\": \"stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN\",      \"amount_out\": \"500\",      \"amount_out_asset\": \"iso4217:BRL\",      \"amount_fee\": \"0.1\",      \"amount_fee_asset\": \"stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN\",      \"started_at\": \"2021-06-11T17:05:32Z\"    }  ]}";
  }

  String requestPendingTransaction() {
    return "{  \"transaction\": {    \"id\": \"82fhs729f63dh0v4\",    \"kind\": \"deposit\",    \"status\": \"pending_external\",    \"status_eta\": 3600,    \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",    \"amount_in\": \"18.34\",    \"amount_out\": \"18.24\",    \"amount_fee\": \"0.1\",    \"started_at\": \"2017-03-20T17:05:32Z\"  }}";
  }

  String requestCompletedTransaction() {
    return "{  \"transaction\": {    \"id\": \"82fhs729f63dh0v4\",    \"kind\": \"deposit\",    \"status\": \"completed\",    \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",    \"amount_in\": \"18.34\",    \"amount_out\": \"18.24\",    \"amount_fee\": \"0.1\",    \"started_at\": \"2017-03-20T17:05:32Z\"  }}";
  }

  String requestPendingTransactions1() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },   {      \"id\": \"82fhs729f63dh0v5\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31094\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },  {      \"id\": \"82fhs729f63dh0v6\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31095\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    }]}";
  }

  String requestPendingTransactions2() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",     \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },   {      \"id\": \"82fhs729f63dh0v5\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31094\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },  {      \"id\": \"82fhs729f63dh0v6\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31095\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    }]}";
  }

  String requestPendingTransactions3() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",     \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },   {      \"id\": \"82fhs729f63dh0v5\",      \"kind\": \"deposit\",      \"status\": \"completed\",   \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31094\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },  {      \"id\": \"82fhs729f63dh0v6\",      \"kind\": \"deposit\",      \"status\": \"pending_external\",      \"status_eta\": 3600,      \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31095\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    }]}";
  }

  String requestCompletedTransactions() {
    return "{  \"transactions\": [    {      \"id\": \"82fhs729f63dh0v4\",      \"kind\": \"deposit\",      \"status\": \"completed\",     \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },   {      \"id\": \"82fhs729f63dh0v5\",      \"kind\": \"deposit\",      \"status\": \"completed\",   \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31094\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    },  {      \"id\": \"82fhs729f63dh0v6\",      \"kind\": \"deposit\",      \"status\": \"completed\",    \"external_transaction_id\": \"2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31095\",      \"amount_in\": \"18.34\",      \"amount_out\": \"18.24\",      \"amount_fee\": \"0.1\",      \"started_at\": \"2017-03-20T17:05:32Z\"    }]}";
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
    Sep6Info sep6Info = await anchor.sep6().info();

    assert(sep6Info.deposit != null);
    assert(sep6Info.deposit!.length == 2);
    assert(sep6Info.deposit?["USD"] != null);

    Sep6DepositInfo depositInfoUSD = sep6Info.deposit!["USD"]!;
    assert(depositInfoUSD.enabled);
    assert(depositInfoUSD.authenticationRequired!);
    assert(depositInfoUSD.feeFixed == null);
    assert(depositInfoUSD.feePercent == null);
    assert(depositInfoUSD.minAmount == 0.1);
    assert(depositInfoUSD.maxAmount == 1000.0);

    Map<String, Sep6FieldInfo>? fieldsInfo = depositInfoUSD.fieldsInfo;
    assert(fieldsInfo != null);
    assert(fieldsInfo!.length == 4);
    assert(fieldsInfo!["email_address"] != null);
    Sep6FieldInfo emailAddress = fieldsInfo!["email_address"]!;
    assert(emailAddress.description ==
        "your email address for transaction status updates");
    assert(emailAddress.optional!);
    assert(fieldsInfo["country_code"]!.choices!.contains("USA"));
    assert(fieldsInfo["type"]!.choices!.contains("SWIFT"));

    Sep6DepositExchangeInfo depositExchangeInfoUSD =
        sep6Info.depositExchange!["USD"]!;
    assert(!depositExchangeInfoUSD.enabled);
    assert(depositExchangeInfoUSD.authenticationRequired!);

    fieldsInfo = depositExchangeInfoUSD.fieldsInfo;
    assert(fieldsInfo != null);
    assert(fieldsInfo!.length == 4);
    assert(fieldsInfo!["email_address"] != null);
    emailAddress = fieldsInfo!["email_address"]!;
    assert(emailAddress.description ==
        "your email address for transaction status updates");
    assert(emailAddress.optional!);
    assert(fieldsInfo["country_code"]!.choices!.contains("USA"));
    assert(fieldsInfo["type"]!.choices!.contains("SWIFT"));

    assert(sep6Info.withdraw!["USD"] != null);
    Sep6WithdrawInfo withdrawInfoUSD = sep6Info.withdraw!["USD"]!;
    assert(withdrawInfoUSD.enabled);
    assert(withdrawInfoUSD.authenticationRequired!);
    assert(withdrawInfoUSD.feeFixed == null);
    assert(withdrawInfoUSD.feePercent == null);
    assert(withdrawInfoUSD.minAmount == 0.1);
    assert(withdrawInfoUSD.maxAmount == 1000.0);

    Map<String, Map<String, Sep6FieldInfo>?>? types = withdrawInfoUSD.types;
    assert(types != null);
    assert(types!.length == 2);
    Map<String, Sep6FieldInfo>? bankAccountFields = types!["bank_account"];
    assert(bankAccountFields != null);
    assert(bankAccountFields!["country_code"]!.choices!.contains("PRI"));
    assert(types["cash"]!["dest"]!.optional!);

    assert(!sep6Info.withdraw!["ETH"]!.enabled);

    assert(sep6Info.withdrawExchange!["USD"] != null);
    Sep6WithdrawExchangeInfo withdrawExchangeInfoUSD =
        sep6Info.withdrawExchange!["USD"]!;
    assert(!withdrawExchangeInfoUSD.enabled);
    assert(withdrawExchangeInfoUSD.authenticationRequired!);

    types = withdrawExchangeInfoUSD.types;
    assert(types != null);
    assert(types!.length == 2);
    bankAccountFields = types!["bank_account"];
    assert(bankAccountFields != null);
    assert(bankAccountFields!["country_code"]!.choices!.contains("PRI"));
    assert(types["cash"]!["dest"]!.optional!);

    assert(!sep6Info.fee!.enabled);
    assert(sep6Info.transactions!.enabled);
    assert(sep6Info.transactions!.authenticationRequired!);
    assert(!sep6Info.transaction!.enabled);
    assert(sep6Info.transaction!.authenticationRequired!);
  });

  test('test deposit bank payment', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }

      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("deposit") &&
          authHeader.contains(jwtToken)) {
        // print(request.url.toString());
        return http.Response(requestBankDeposit(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    var depositParams = Sep6DepositParams(
        assetCode: 'USD', account: accountId, amount: '123.123');
    var authToken = AuthToken(jwtToken);

    var depositResponse = await anchor.sep6().deposit(depositParams, authToken);

    assert(depositResponse is Sep6DepositSuccess);
    depositResponse = depositResponse as Sep6DepositSuccess;

    assert(depositResponse.how ==
        "Make a payment to Bank: 121122676 Account: 13719713158835300");
    assert(depositResponse.id == "9421871e-0623-4356-b7b5-5996da122f3e");
    assert(depositResponse.feeFixed == null);

    var instructions = depositResponse.instructions;
    assert(instructions != null);

    var bankNumberKey = flutter_sdk.OrganizationKYCFields.key_prefix +
        flutter_sdk.FinancialAccountKYCFields.bank_number_field_key;
    assert(instructions!.containsKey(bankNumberKey));
    var bankNumberInstruction = instructions![bankNumberKey];
    assert(bankNumberInstruction != null);
    assert(bankNumberInstruction!.value == '121122676');
    assert(bankNumberInstruction!.description == 'US bank routing number');

    var bankAccountNumberKey = flutter_sdk.OrganizationKYCFields.key_prefix +
        flutter_sdk.FinancialAccountKYCFields.bank_account_number_field_key;
    assert(instructions.containsKey(bankAccountNumberKey));
    var bankAccountNumberInstruction = instructions[bankAccountNumberKey];
    assert(bankAccountNumberInstruction != null);
    assert(bankAccountNumberInstruction!.value == '13719713158835300');
    assert(
        bankAccountNumberInstruction!.description == 'US bank account number');
  });

  test('test deposit btc success', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }

      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("deposit") &&
          authHeader.contains(jwtToken)) {
        // print(request.url.toString());
        return http.Response(requestBTCDeposit(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    var depositParams = Sep6DepositParams(
        assetCode: "BTC", account: accountId, amount: "3.123");
    var authToken = AuthToken(jwtToken);
    var depositResponse = await anchor.sep6().deposit(depositParams, authToken);

    assert(depositResponse is Sep6DepositSuccess);
    depositResponse = depositResponse as Sep6DepositSuccess;

    assert(depositResponse.how ==
        "Make a payment to Bitcoin address 1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB");
    assert(depositResponse.id == "9421871e-0623-4356-b7b5-5996da122f3e");
    assert(depositResponse.feeFixed == 0.0002);

    var instructions = depositResponse.instructions;
    assert(instructions != null);
    var cryptoAddressKey = flutter_sdk.OrganizationKYCFields.key_prefix +
        flutter_sdk.FinancialAccountKYCFields.crypto_address_field_key;
    assert(instructions!.containsKey(cryptoAddressKey));
    var cryptoAddressInstruction = instructions![cryptoAddressKey];
    assert(cryptoAddressInstruction != null);
    assert(cryptoAddressInstruction!.value ==
        '1Nh7uHdvY6fNwtQtM1G5EZAFPLC33B59rB');
    assert(cryptoAddressInstruction!.description == 'Bitcoin address');
  });

  test('test deposit ripple success', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }

      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("deposit") &&
          authHeader.contains(jwtToken)) {
        // print(request.url.toString());
        return http.Response(requestRippleDeposit(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    var depositParams = Sep6DepositParams(
        assetCode: "XRP", account: accountId, amount: "300.0");
    var authToken = AuthToken(jwtToken);
    var depositResponse = await anchor.sep6().deposit(depositParams, authToken);

    assert(depositResponse is Sep6DepositSuccess);
    depositResponse = depositResponse as Sep6DepositSuccess;

    assert(depositResponse.how ==
        "Make a payment to Ripple address rNXEkKCxvfLcM1h4HJkaj2FtmYuAWrHGbf with tag 88");
    assert(depositResponse.id == "9421871e-0623-4356-b7b5-5996da122f3e");
    assert(depositResponse.eta == 60);
    assert(depositResponse.feePercent == 0.1);
    assert(depositResponse.extraInfo!.message ==
        "You must include the tag. If the amount is more than 1000 XRP, deposit will take 24h to complete.");

    var instructions = depositResponse.instructions;
    assert(instructions != null);

    var cryptoAddressKey = flutter_sdk.OrganizationKYCFields.key_prefix +
        flutter_sdk.FinancialAccountKYCFields.crypto_address_field_key;
    assert(instructions!.containsKey(cryptoAddressKey));
    var cryptoAddressInstruction = instructions![cryptoAddressKey];
    assert(cryptoAddressInstruction != null);
    assert(cryptoAddressInstruction!.value ==
        'rNXEkKCxvfLcM1h4HJkaj2FtmYuAWrHGbf');
    assert(cryptoAddressInstruction!.description == 'Ripple address');

    var cryptoMemoKey = flutter_sdk.OrganizationKYCFields.key_prefix +
        flutter_sdk.FinancialAccountKYCFields.crypto_memo_field_key;
    assert(instructions.containsKey(cryptoMemoKey));
    var cryptoMemoInstruction = instructions[cryptoMemoKey];
    assert(cryptoMemoInstruction != null);
    assert(cryptoMemoInstruction!.value == '88');
    assert(cryptoMemoInstruction!.description == 'Ripple tag');
  });

  test('test deposit MXN success', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }

      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("deposit") &&
          authHeader.contains(jwtToken)) {
        // print(request.url.toString());
        return http.Response(requestMXNDeposit(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    var depositParams = Sep6DepositParams(
        assetCode: "MXN", account: accountId, amount: "120.0");
    var authToken = AuthToken(jwtToken);
    var depositResponse = await anchor.sep6().deposit(depositParams, authToken);

    assert(depositResponse is Sep6DepositSuccess);
    depositResponse = depositResponse as Sep6DepositSuccess;

    assert(depositResponse.how ==
        "Make a payment to Bank: STP Account: 646180111803859359");
    assert(depositResponse.id == "9421871e-0623-4356-b7b5-5996da122f3e");
    assert(depositResponse.eta == 1800);

    var instructions = depositResponse.instructions;
    assert(instructions != null);

    var clabeNumberKey = flutter_sdk.OrganizationKYCFields.key_prefix +
        flutter_sdk.FinancialAccountKYCFields.clabe_number_field_key;
    assert(instructions!.containsKey(clabeNumberKey));
    var clabeNumberInstruction = instructions![clabeNumberKey];
    assert(clabeNumberInstruction != null);
    assert(clabeNumberInstruction!.value == '646180111803859359');
    assert(clabeNumberInstruction!.description == 'CLABE number');
  });

  test('test withdraw success', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }

      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("withdraw") &&
          authHeader.contains(jwtToken)) {
        // print(request.url.toString());
        return http.Response(requestWithdrawSuccess(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    var withdrawParams = Sep6WithdrawParams(
        assetCode: "XLM",
        type: "crypto",
        dest: "GCTTGO5ABSTHABXWL2FMHPZ2XFOZDXJYJN5CKFRKXMPAAWZW3Y3JZ3JK",
        account: accountId,
        amount: "120.0");
    var authToken = AuthToken(jwtToken);
    var withdrawResponse =
        await anchor.sep6().withdraw(withdrawParams, authToken);

    assert(withdrawResponse is Sep6WithdrawSuccess);
    withdrawResponse = withdrawResponse as Sep6WithdrawSuccess;

    assert(withdrawResponse.accountId ==
        "GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ");
    assert(withdrawResponse.memoType == "id");
    assert(withdrawResponse.memo == "123");
    assert(withdrawResponse.id == "9421871e-0623-4356-b7b5-5996da122f3e");
  });

  test('test deposit-exchange', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }

      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("deposit-exchange") &&
          authHeader.contains(jwtToken)) {
        var url = request.url.toString();
        //print(url);
        assert(url.contains(
            "GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ"));
        assert(url.contains("XYZ"));
        assert(url.contains("iso4217%3AUSD"));
        assert(url.contains("100"));
        assert(url.contains("999"));
        assert(url.contains("282837"));

        return http.Response(requestBankDeposit(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    var params = Sep6DepositExchangeParams(
        destinationAssetCode: 'XYZ',
        sourceAssetId: FiatAssetId('USD'),
        quoteId: '282837',
        amount: '100',
        account: 'GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ',
        locationId: '999');

    var authToken = AuthToken(jwtToken);
    var response = await anchor.sep6().depositExchange(params, authToken);

    assert(response is Sep6DepositSuccess);
    response = response as Sep6DepositSuccess;

    assert(response.how ==
        "Make a payment to Bank: 121122676 Account: 13719713158835300");
    assert(response.id == "9421871e-0623-4356-b7b5-5996da122f3e");
    assert(response.feeFixed == null);
  });

  test('test withdraw exchange', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("withdraw-exchange") &&
          authHeader.contains(jwtToken)) {
        var url = request.url.toString();
        // print(url);
        assert(url.contains("XYZ"));
        assert(url.contains("iso4217%3AUSD"));
        assert(url.contains("700"));
        assert(url.contains("999"));
        assert(url.contains("282837"));
        return http.Response(requestWithdrawSuccess(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);
    var params = Sep6WithdrawExchangeParams(
        sourceAssetCode: 'XYZ',
        destinationAssetId: FiatAssetId('USD'),
        quoteId: '282837',
        amount: '700',
        type: 'bank_account',
        locationId: '999');

    var authToken = AuthToken(jwtToken);
    var response = await anchor.sep6().withdrawExchange(params, authToken);

    assert(response is Sep6WithdrawSuccess);
    response = response as Sep6WithdrawSuccess;

    assert(response.accountId ==
        "GCIBUCGPOHWMMMFPFTDWBSVHQRT4DIBJ7AD6BZJYDITBK2LCVBYW7HUQ");
    assert(response.memoType == "id");
    assert(response.memo == "123");
    assert(response.id == "9421871e-0623-4356-b7b5-5996da122f3e");
  });

  test('test deposit customer information needed', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("deposit") &&
          authHeader.contains(jwtToken)) {
        // print(request.url.toString());
        return http.Response(requestCustomerInformationNeeded(), 403);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    var depositParams = Sep6DepositParams(
        assetCode: "MXN", account: accountId, amount: "120.0");
    var authToken = AuthToken(jwtToken);
    var depositResponse = await anchor.sep6().deposit(depositParams, authToken);

    assert(depositResponse is Sep6MissingKYC);
  });

  test('test deposit customer information status', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("deposit") &&
          authHeader.contains(jwtToken)) {
        // print(request.url.toString());
        return http.Response(requestCustomerInformationStatus(), 403);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    var depositParams = Sep6DepositParams(
        assetCode: "MXN", account: accountId, amount: "120.0");
    var authToken = AuthToken(jwtToken);
    var depositResponse = await anchor.sep6().deposit(depositParams, authToken);

    assert(depositResponse is Sep6Pending);
  });

  test('test get transactions for asset', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("transactions") &&
          authHeader.contains(jwtToken)) {
        // print(request.url.toString());
        return http.Response(requestTransactions(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    var authToken = AuthToken(jwtToken);
    var transactions = await anchor
        .sep6()
        .getTransactionsForAsset(authToken: authToken, assetCode: "XLM");

    assert(transactions.length == 6);
    assert(transactions.first.id == "82fhs729f63dh0v4");
    assert(transactions.first.kind == "deposit");
    assert(transactions.first.status == TransactionStatus.pendingExternal);
    assert(transactions.first.statusEta == 3600);
    assert(transactions.first.externalTransactionId ==
        "2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093");
    assert(transactions.first.amountIn == "18.34");
    assert(transactions.first.amountOut == "18.24");
    assert(transactions.first.amountFee == "0.1");
    assert(
        transactions.first.startedAt == DateTime.parse("2017-03-20T17:05:32Z"));

    var transaction = transactions[1];
    assert(transaction.id == "52fys79f63dh3v2");
    assert(transaction.kind == "deposit-exchange");
    assert(transaction.status == TransactionStatus.pendingAnchor);
    assert(transaction.statusEta == 3600);
    assert(transaction.externalTransactionId ==
        "2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093");
    assert(transaction.amountIn == "500");
    assert(transaction.amountInAsset == "iso4217:BRL");
    assert(transaction.amountOut == "100");
    assert(transaction.amountOutAsset ==
        "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN");
    assert(transaction.amountFee == "0.1");
    assert(transaction.amountFeeAsset == "iso4217:BRL");
    assert(transaction.startedAt == DateTime.parse("2021-06-11T17:05:32Z"));

    transaction = transactions[2];
    assert(transaction.id == "82fhs729f63dh0v4");
    assert(transaction.kind == "withdrawal");
    assert(transaction.status == TransactionStatus.completed);
    assert(transaction.statusEta == null);
    assert(transaction.amountIn == "510");
    assert(transaction.amountInAsset == null);
    assert(transaction.amountOut == "490");
    assert(transaction.amountOutAsset == null);
    assert(transaction.amountFee == "5");
    assert(transaction.amountFeeAsset == null);
    assert(transaction.startedAt == DateTime.parse("2017-03-20T17:00:02Z"));
    assert(transaction.completedAt == DateTime.parse("2017-03-20T17:09:58Z"));
    assert(transaction.stellarTransactionId ==
        "17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a");
    assert(transaction.externalTransactionId == "1238234");
    assert(transaction.withdrawAnchorAccount ==
        "GBANAGOAXH5ONSBI2I6I5LHP2TCRHWMZIAMGUQH2TNKQNCOGJ7GC3ZOL");
    assert(transaction.withdrawMemo == "186384");
    assert(transaction.withdrawMemoType == "id");

    var refunds = transaction.refunds!;
    assert(refunds.amountRefunded == "10");
    assert(refunds.amountFee == "5");
    var payments = refunds.payments;
    assert(payments.length == 1);
    var payment = payments.first;
    assert(payment.id ==
        "b9d0b2292c4e09e8eb22d036171491e87b8d2086bf8b265874c8d182cb9c9020");
    assert(payment.idType == "stellar");
    assert(payment.amount == "10");
    assert(payment.fee == "5");

    transaction = transactions[3];
    assert(transaction.id == "72fhs729f63dh0v1");
    assert(transaction.kind == "deposit");
    assert(transaction.status == TransactionStatus.completed);
    assert(transaction.statusEta == null);
    assert(transaction.amountIn == "510");
    assert(transaction.amountInAsset == null);
    assert(transaction.amountOut == "490");
    assert(transaction.amountOutAsset == null);
    assert(transaction.amountFee == "5");
    assert(transaction.amountFeeAsset == null);
    assert(transaction.startedAt == DateTime.parse("2017-03-20T17:00:02Z"));
    assert(transaction.completedAt == DateTime.parse("2017-03-20T17:09:58Z"));
    assert(transaction.stellarTransactionId ==
        "17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a");
    assert(transaction.externalTransactionId == "1238234");
    assert(transaction.from == "AJ3845SAD");
    assert(transaction.to ==
        "GBITQ4YAFKD2372TNAMNHQ4JV5VS3BYKRK4QQR6FOLAR7XAHC3RVGVVJ");

    refunds = transaction.refunds!;
    assert(refunds.amountRefunded == "10");
    assert(refunds.amountFee == "5");
    payments = refunds.payments;
    assert(payments.length == 1);
    payment = payments.first;
    assert(payment.id == "104201");
    assert(payment.idType == "external");
    assert(payment.amount == "10");
    assert(payment.fee == "5");

    transaction = transactions[4];
    assert(transaction.id == "52fys79f63dh3v1");
    assert(transaction.kind == "withdrawal");
    assert(
        transaction.status == TransactionStatus.pendingTransactionInfoUpdate);
    assert(transaction.statusEta == null);
    assert(transaction.amountIn == "750.00");
    assert(transaction.amountInAsset == null);
    assert(transaction.amountOut == null);
    assert(transaction.amountOutAsset == null);
    assert(transaction.amountFee == null);
    assert(transaction.amountFeeAsset == null);
    assert(transaction.startedAt == DateTime.parse("2017-03-20T17:00:02Z"));
    assert(transaction.completedAt == null);
    assert(transaction.requiredInfoMessage ==
        "We were unable to send funds to the provided bank account. Bank error: 'Account does not exist'. Please provide the correct bank account address.");
    var requiredInfoUpdates = transaction.requiredInfoUpdates!;
    assert(requiredInfoUpdates.length == 2);
    var dest = requiredInfoUpdates['dest']!;
    assert(dest.description == "your bank account number");
    var destExtra = requiredInfoUpdates['dest_extra']!;
    assert(destExtra.description == "your routing number");

    transaction = transactions.last;
    assert(transaction.id == "52fys79f63dh3v2");
    assert(transaction.kind == "withdrawal-exchange");
    assert(transaction.status == TransactionStatus.pendingAnchor);
    assert(transaction.statusEta == 3600);
    assert(transaction.amountIn == "100");
    assert(transaction.amountInAsset ==
        "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN");
    assert(transaction.amountOut == "500");
    assert(transaction.amountOutAsset == "iso4217:BRL");
    assert(transaction.amountFee == "0.1");
    assert(transaction.amountFeeAsset ==
        "stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN");
    assert(transaction.startedAt == DateTime.parse("2021-06-11T17:05:32Z"));
  });

  test('test get transaction by', () async {
    http.Client anchorMock = MockClient((request) async {
      if (request.url.toString().contains(anchorDomain) &&
          request.url.toString().contains("stellar.toml")) {
        return http.Response(anchorToml, 200);
      }
      String authHeader = request.headers["Authorization"]!;
      if (request.url.toString().startsWith(serviceAddress) &&
          request.method == "GET" &&
          request.url.toString().contains("transaction") &&
          authHeader.contains(jwtToken)) {
        // print(request.url.toString());
        return http.Response(requestPendingTransaction(), 200);
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    var authToken = AuthToken(jwtToken);

    var transaction = await anchor.sep6().getTransactionBy(
        authToken: authToken,
        id: "82fhs729f63dh0v4",
        stellarTransactionId:
            "17a670bc424ff5ce3b386dbfaae9990b66a2a37b4fbe51547e8794962a3f9e6a");

    assert(transaction.id == "82fhs729f63dh0v4");
    assert(transaction.kind == "deposit");
    assert(transaction.status == TransactionStatus.pendingExternal);
    assert(transaction.statusEta == 3600);
    assert(transaction.externalTransactionId ==
        "2dd16cb409513026fbe7defc0c6f826c2d2c65c3da993f747d09bf7dafd31093");
    assert(transaction.amountIn == "18.34");
    assert(transaction.amountOut == "18.24");
    assert(transaction.amountFee == "0.1");
    assert(transaction.startedAt == DateTime.parse("2017-03-20T17:05:32Z"));
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
          return http.Response(requestCompletedTransaction(), 200);
        }
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    AuthToken token = AuthToken(jwtToken);
    Sep6 sep6 = anchor.sep6();
    Watcher watcher = sep6.watcher();
    WatcherResult result =
        watcher.watchOneTransaction(token, "82fhs729f63dh0v4");

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
        } else {
          return http.Response(requestCompletedTransactions(), 200);
        }
      }

      final mapJson = {'error': "Bad request"};
      return http.Response(json.encode(mapJson), 400);
    });

    Wallet wallet = Wallet.testNet;
    Anchor anchor = wallet.anchor(anchorDomain, httpClient: anchorMock);

    AuthToken token = AuthToken(jwtToken);
    Sep6 sep6 = anchor.sep6();
    Watcher watcher = sep6.watcher();
    WatcherResult result = watcher.watchAsset(
        token,
        IssuedAssetId(
            code: "USD",
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
            assert(TransactionStatus.pendingExternal == event.status);
          } else {
            assert(TransactionStatus.completed == event.status);
            if (counter == 4) {
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
