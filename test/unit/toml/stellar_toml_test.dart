// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  // A fully populated stellar.toml fixture exercising every general-info field,
  // the documentation table, principals, currencies and validators.
  const fullToml = '''
VERSION = "2.7.0"
NETWORK_PASSPHRASE = "Public Global Stellar Network ; September 2015"
FEDERATION_SERVER = "https://api.example.com/federation"
AUTH_SERVER = "https://api.example.com/auth"
TRANSFER_SERVER = "https://api.example.com/sep6"
TRANSFER_SERVER_SEP0024 = "https://api.example.com/sep24"
KYC_SERVER = "https://api.example.com/kyc"
WEB_AUTH_ENDPOINT = "https://api.example.com/webauth"
SIGNING_KEY = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
HORIZON_URL = "https://horizon.example.com"
ACCOUNTS = [
  "GA2HGBJIJKI6O4XEM7CZWY5PS6GKSXL6D34ERAJYQSPYA6X6AI7HYW36",
  "GD2HGBJIJKI6O4XEM7CZWY5PS6GKSXL6D34ERAJYQSPYA6X6AI7HYW36"
]
URI_REQUEST_SIGNING_KEY = "GCCBNUOPDPDWBVBKICFD3JFL7HZUR2K6BSRMQQDPC2WLPGOSC2PEKMP5"
DIRECT_PAYMENT_SERVER = "https://api.example.com/sep31"
ANCHOR_QUOTE_SERVER = "https://api.example.com/sep38"

[DOCUMENTATION]
ORG_NAME = "Example Organization"
ORG_DBA = "Example DBA"
ORG_URL = "https://example.com"
ORG_LOGO = "https://example.com/logo.png"
ORG_DESCRIPTION = "An example anchor organization."
ORG_PHYSICAL_ADDRESS = "123 Example Street, Example City"
ORG_PHYSICAL_ADDRESS_ATTESTATION = "https://example.com/address.pdf"
ORG_PHONE_NUMBER = "+14155552671"
ORG_PHONE_NUMBER_ATTESTATION = "https://example.com/phone.pdf"
ORG_KEYBASE = "exampleorg"
ORG_TWITTER = "exampleorg"
ORG_GITHUB = "exampleorg"
ORG_OFFICIAL_EMAIL = "official@example.com"
ORG_SUPPORT_EMAIL = "support@example.com"
ORG_LICENSING_AUTHORITY = "Example Licensing Authority"
ORG_LICENSE_TYPE = "Money Services Business"
ORG_LICENSE_NUMBER = "MSB-12345"

[[PRINCIPALS]]
name = "Jane Doe"
email = "jane@example.com"
keybase = "janedoe"
telegram = "janedoe_tg"
twitter = "janedoe_tw"
github = "janedoe_gh"
id_photo_hash = "id-hash-jane"
verification_photo_hash = "verify-hash-jane"

[[PRINCIPALS]]
name = "John Roe"
email = "john@example.com"

[[CURRENCIES]]
code = "USD"
issuer = "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM"
status = "live"
display_decimals = 2
name = "US Dollar"
desc = "Anchored US Dollar."
conditions = "No conditions."
image = "https://example.com/usd.png"
fixed_number = 1000
max_number = 2000
is_unlimited = false
is_asset_anchored = true
anchor_asset_type = "fiat"
anchor_asset = "USD"
attestation_of_reserve = "https://example.com/reserve.pdf"
redemption_instructions = "Contact support to redeem."
collateral_addresses = ["GADDR1EXAMPLE", "GADDR2EXAMPLE"]
collateral_address_messages = ["msg1", "msg2"]
collateral_address_signatures = ["sig1", "sig2"]
regulated = true
approval_server = "https://example.com/approve"
approval_criteria = "KYC required."

[[CURRENCIES]]
code = "BTC"
issuer = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"

[[VALIDATORS]]
ALIAS = "example-val-1"
DISPLAY_NAME = "Example Validator 1"
PUBLIC_KEY = "GCMITQHQU634V3WHQEX4XQVRSFZJ4GLY5KZ5T2BS2J3CR3DZSPLD5WHC"
HOST = "core1.example.com:11625"
HISTORY = "https://history.example.com/1/"

[[VALIDATORS]]
ALIAS = "example-val-2"
DISPLAY_NAME = "Example Validator 2"
PUBLIC_KEY = "GDXJ2L6CXHRQOJ6HGT5DLUOKSVMNTEYCNFQAH5GILHNFNCBZ2J2LV6LM"
HOST = "core2.example.com:11625"
HISTORY = "https://history.example.com/2/"
''';

  group('TomlInfo.from Tests', () {
    late TomlInfo info;

    setUp(() {
      info = TomlInfo.from(flutter_sdk.StellarToml(fullToml));
    });

    test('maps all general information fields', () {
      expect(info.version, '2.7.0');
      expect(info.networkPassphrase,
          'Public Global Stellar Network ; September 2015');
      expect(info.federationServer, 'https://api.example.com/federation');
      expect(info.authServer, 'https://api.example.com/auth');
      expect(info.transferServer, 'https://api.example.com/sep6');
      expect(info.transferServerSep24, 'https://api.example.com/sep24');
      expect(info.webAuthEndpoint, 'https://api.example.com/webauth');
      expect(info.signingKey,
          'GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP');
      expect(info.horizonUrl, 'https://horizon.example.com');
      expect(info.uriRequestSigningKey,
          'GCCBNUOPDPDWBVBKICFD3JFL7HZUR2K6BSRMQQDPC2WLPGOSC2PEKMP5');
      expect(info.directPaymentServer, 'https://api.example.com/sep31');
      expect(info.anchorQuoteServer, 'https://api.example.com/sep38');
    });

    test('maps kYCServer to kycServer', () {
      // The base SDK field is named kYCServer; the wallet SDK exposes kycServer.
      expect(info.kycServer, 'https://api.example.com/kyc');
    });

    test('maps the accounts list', () {
      expect(info.accounts, isNotNull);
      expect(info.accounts, hasLength(2));
      expect(info.accounts!.first,
          'GA2HGBJIJKI6O4XEM7CZWY5PS6GKSXL6D34ERAJYQSPYA6X6AI7HYW36');
      expect(info.accounts!.last,
          'GD2HGBJIJKI6O4XEM7CZWY5PS6GKSXL6D34ERAJYQSPYA6X6AI7HYW36');
    });

    test('maps documentation including orgDBA to orgDba', () {
      expect(info.documentation, isNotNull);
      final doc = info.documentation!;
      expect(doc.orgName, 'Example Organization');
      // The base SDK field is named orgDBA; the wallet SDK exposes orgDba.
      expect(doc.orgDba, 'Example DBA');
      expect(doc.orgUrl, 'https://example.com');
      expect(doc.orgLogo, 'https://example.com/logo.png');
      expect(doc.orgDescription, 'An example anchor organization.');
      expect(doc.orgPhysicalAddress, '123 Example Street, Example City');
      expect(doc.orgPhysicalAddressAttestation,
          'https://example.com/address.pdf');
      expect(doc.orgPhoneNumber, '+14155552671');
      expect(doc.orgPhoneNumberAttestation, 'https://example.com/phone.pdf');
      expect(doc.orgKeybase, 'exampleorg');
      expect(doc.orgTwitter, 'exampleorg');
      expect(doc.orgGithub, 'exampleorg');
      expect(doc.orgOfficialEmail, 'official@example.com');
      expect(doc.orgSupportEmail, 'support@example.com');
      expect(doc.orgLicensingAuthority, 'Example Licensing Authority');
      expect(doc.orgLicenseType, 'Money Services Business');
      expect(doc.orgLicenseNumber, 'MSB-12345');
    });

    test('populates principals from PRINCIPALS', () {
      expect(info.principals, isNotNull);
      expect(info.principals, hasLength(2));

      final jane = info.principals![0];
      expect(jane.name, 'Jane Doe');
      expect(jane.email, 'jane@example.com');
      expect(jane.keybase, 'janedoe');
      expect(jane.telegram, 'janedoe_tg');
      expect(jane.twitter, 'janedoe_tw');
      expect(jane.github, 'janedoe_gh');
      expect(jane.idPhotoHash, 'id-hash-jane');
      expect(jane.verificationPhotoHash, 'verify-hash-jane');

      final john = info.principals![1];
      expect(john.name, 'John Roe');
      expect(john.email, 'john@example.com');
      expect(john.keybase, isNull);
      expect(john.telegram, isNull);
    });

    test('populates currencies from CURRENCIES', () {
      expect(info.currencies, isNotNull);
      expect(info.currencies, hasLength(2));

      final usd = info.currencies![0];
      expect(usd.code, 'USD');
      expect(usd.issuer,
          'GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM');
      expect(usd.status, 'live');
      expect(usd.displayDecimals, 2);
      expect(usd.name, 'US Dollar');
      expect(usd.desc, 'Anchored US Dollar.');
      expect(usd.conditions, 'No conditions.');
      expect(usd.image, 'https://example.com/usd.png');
      expect(usd.fixedNumber, 1000);
      expect(usd.maxNumber, 2000);
      expect(usd.isUnlimited, false);
      expect(usd.isAssetAnchored, true);
      expect(usd.anchorAssetType, 'fiat');
      expect(usd.anchorAsset, 'USD');
      expect(usd.attestationOfReserve, 'https://example.com/reserve.pdf');
      expect(usd.redemptionInstructions, 'Contact support to redeem.');
      expect(usd.collateralAddresses, ['GADDR1EXAMPLE', 'GADDR2EXAMPLE']);
      expect(usd.collateralAddressMessages, ['msg1', 'msg2']);
      expect(usd.collateralAddressSignatures, ['sig1', 'sig2']);
      expect(usd.regulated, true);
      expect(usd.approvalServer, 'https://example.com/approve');
      expect(usd.approvalCriteria, 'KYC required.');

      final btc = info.currencies![1];
      expect(btc.code, 'BTC');
      expect(btc.issuer,
          'GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP');
      expect(btc.status, isNull);
      expect(btc.collateralAddresses, isNull);
    });

    test('populates validators from VALIDATORS', () {
      expect(info.validators, isNotNull);
      expect(info.validators, hasLength(2));

      final val1 = info.validators![0];
      expect(val1.alias, 'example-val-1');
      expect(val1.displayName, 'Example Validator 1');
      expect(val1.publicKey,
          'GCMITQHQU634V3WHQEX4XQVRSFZJ4GLY5KZ5T2BS2J3CR3DZSPLD5WHC');
      expect(val1.host, 'core1.example.com:11625');
      expect(val1.history, 'https://history.example.com/1/');

      final val2 = info.validators![1];
      expect(val2.alias, 'example-val-2');
      expect(val2.publicKey,
          'GDXJ2L6CXHRQOJ6HGT5DLUOKSVMNTEYCNFQAH5GILHNFNCBZ2J2LV6LM');
    });

    test('leaves documentation, principals, currencies, validators null when absent', () {
      const minimalToml = '''
VERSION = "2.7.0"
SIGNING_KEY = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
''';
      final minimal = TomlInfo.from(flutter_sdk.StellarToml(minimalToml));

      expect(minimal.documentation, isNull);
      expect(minimal.principals, isNull);
      expect(minimal.currencies, isNull);
      expect(minimal.validators, isNull);

      // General-info string fields that are absent stay null.
      expect(minimal.networkPassphrase, isNull);
      expect(minimal.transferServer, isNull);
      expect(minimal.kycServer, isNull);
      expect(minimal.webAuthEndpoint, isNull);

      // The base SDK initializes accounts to an empty list (never null), so an
      // absent ACCOUNTS section yields an empty list rather than null.
      expect(minimal.accounts, isNotNull);
      expect(minimal.accounts, isEmpty);
    });
  });

  group('TomlInfo.hasAuth Tests', () {
    test('is true when both webAuthEndpoint and signingKey are present', () {
      const toml = '''
WEB_AUTH_ENDPOINT = "https://api.example.com/webauth"
SIGNING_KEY = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      expect(info.hasAuth, isTrue);
    });

    test('is false when only webAuthEndpoint is present', () {
      const toml = '''
WEB_AUTH_ENDPOINT = "https://api.example.com/webauth"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      expect(info.hasAuth, isFalse);
    });

    test('is false when only signingKey is present', () {
      const toml = '''
SIGNING_KEY = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      expect(info.hasAuth, isFalse);
    });

    test('is false when neither is present', () {
      const toml = '''
VERSION = "2.7.0"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      expect(info.hasAuth, isFalse);
    });
  });

  group('TomlInfo.services Tests', () {
    test('all services null when no relevant fields are present', () {
      const toml = '''
VERSION = "2.7.0"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep6, isNull);
      expect(services.sep10, isNull);
      expect(services.sep12, isNull);
      expect(services.sep24, isNull);
      expect(services.sep31, isNull);
    });

    test('sep6 present when transferServer set, forwarding anchorQuoteServer', () {
      const toml = '''
TRANSFER_SERVER = "https://api.example.com/sep6"
ANCHOR_QUOTE_SERVER = "https://api.example.com/sep38"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep6, isNotNull);
      expect(services.sep6!.transferServer, 'https://api.example.com/sep6');
      expect(services.sep6!.anchorQuoteServer, 'https://api.example.com/sep38');

      // Only sep6 is configured here.
      expect(services.sep10, isNull);
      expect(services.sep12, isNull);
      expect(services.sep24, isNull);
      expect(services.sep31, isNull);
    });

    test('sep6 anchorQuoteServer is null when not set', () {
      const toml = '''
TRANSFER_SERVER = "https://api.example.com/sep6"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep6, isNotNull);
      expect(services.sep6!.transferServer, 'https://api.example.com/sep6');
      expect(services.sep6!.anchorQuoteServer, isNull);
    });

    test('sep10 present only when hasAuth is true', () {
      const toml = '''
WEB_AUTH_ENDPOINT = "https://api.example.com/webauth"
SIGNING_KEY = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep10, isNotNull);
      expect(services.sep10!.webAuthEndpoint, 'https://api.example.com/webauth');
      expect(services.sep10!.signingKey,
          'GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP');
    });

    test('sep10 absent when only webAuthEndpoint present (no signingKey)', () {
      const toml = '''
WEB_AUTH_ENDPOINT = "https://api.example.com/webauth"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      expect(info.services.sep10, isNull);
    });

    test('sep12 present when kycServer set, forwarding signingKey', () {
      const toml = '''
KYC_SERVER = "https://api.example.com/kyc"
SIGNING_KEY = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep12, isNotNull);
      expect(services.sep12!.kycServer, 'https://api.example.com/kyc');
      expect(services.sep12!.signingKey,
          'GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP');
    });

    test('sep12 signingKey is null when only kycServer is present', () {
      const toml = '''
KYC_SERVER = "https://api.example.com/kyc"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep12, isNotNull);
      expect(services.sep12!.kycServer, 'https://api.example.com/kyc');
      expect(services.sep12!.signingKey, isNull);
    });

    test('sep24 present when transferServerSep24 set, hasAuth false without auth', () {
      const toml = '''
TRANSFER_SERVER_SEP0024 = "https://api.example.com/sep24"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep24, isNotNull);
      expect(services.sep24!.transferServerSep24,
          'https://api.example.com/sep24');
      expect(services.sep24!.hasAuth, isFalse);
    });

    test('sep24 hasAuth true when both transferServerSep24 and auth present', () {
      const toml = '''
TRANSFER_SERVER_SEP0024 = "https://api.example.com/sep24"
WEB_AUTH_ENDPOINT = "https://api.example.com/webauth"
SIGNING_KEY = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep24, isNotNull);
      expect(services.sep24!.hasAuth, isTrue);
      // Auth presence also activates sep10.
      expect(services.sep10, isNotNull);
    });

    test('sep31 present when directPaymentServer set, forwarding fields', () {
      const toml = '''
DIRECT_PAYMENT_SERVER = "https://api.example.com/sep31"
KYC_SERVER = "https://api.example.com/kyc"
ANCHOR_QUOTE_SERVER = "https://api.example.com/sep38"
WEB_AUTH_ENDPOINT = "https://api.example.com/webauth"
SIGNING_KEY = "GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep31, isNotNull);
      expect(services.sep31!.directPaymentServer,
          'https://api.example.com/sep31');
      expect(services.sep31!.kycServer, 'https://api.example.com/kyc');
      expect(services.sep31!.anchorQuoteServer, 'https://api.example.com/sep38');
      expect(services.sep31!.hasAuth, isTrue);
    });

    test('sep31 hasAuth false and forwarded fields null when minimal', () {
      const toml = '''
DIRECT_PAYMENT_SERVER = "https://api.example.com/sep31"
''';
      final info = TomlInfo.from(flutter_sdk.StellarToml(toml));
      final services = info.services;

      expect(services.sep31, isNotNull);
      expect(services.sep31!.directPaymentServer,
          'https://api.example.com/sep31');
      expect(services.sep31!.hasAuth, isFalse);
      expect(services.sep31!.kycServer, isNull);
      expect(services.sep31!.anchorQuoteServer, isNull);
    });

    test('all services present and wired from the full fixture', () {
      final info = TomlInfo.from(flutter_sdk.StellarToml(fullToml));
      final services = info.services;

      expect(services.sep6, isNotNull);
      expect(services.sep6!.transferServer, 'https://api.example.com/sep6');
      expect(services.sep6!.anchorQuoteServer, 'https://api.example.com/sep38');

      expect(services.sep10, isNotNull);
      expect(services.sep10!.webAuthEndpoint, 'https://api.example.com/webauth');
      expect(services.sep10!.signingKey,
          'GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP');

      expect(services.sep12, isNotNull);
      expect(services.sep12!.kycServer, 'https://api.example.com/kyc');
      expect(services.sep12!.signingKey,
          'GBWMCCC3NHSKLAOJDBKKYW7SSH2PFTTNVFKWSGLWGDLEBKLOVP5JLBBP');

      expect(services.sep24, isNotNull);
      expect(services.sep24!.transferServerSep24,
          'https://api.example.com/sep24');
      expect(services.sep24!.hasAuth, isTrue);

      expect(services.sep31, isNotNull);
      expect(services.sep31!.directPaymentServer,
          'https://api.example.com/sep31');
      expect(services.sep31!.kycServer, 'https://api.example.com/kyc');
      expect(services.sep31!.anchorQuoteServer, 'https://api.example.com/sep38');
      expect(services.sep31!.hasAuth, isTrue);
    });
  });

  group('InfoCurrency Tests', () {
    test('from maps all currency fields', () {
      final currency = flutter_sdk.Currency()
        ..code = 'USDC'
        ..issuer = 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN'
        ..codeTemplate = 'USD?'
        ..status = 'live'
        ..displayDecimals = 7
        ..name = 'USD Coin'
        ..desc = 'A fully backed stablecoin.'
        ..conditions = 'Subject to terms.'
        ..image = 'https://example.com/usdc.png'
        ..fixedNumber = 5
        ..maxNumber = 10
        ..isUnlimited = false
        ..isAssetAnchored = true
        ..anchorAssetType = 'fiat'
        ..anchorAsset = 'USD'
        ..attestationOfReserve = 'https://example.com/attest.pdf'
        ..redemptionInstructions = 'Redeem at example.com.'
        ..collateralAddresses = ['GADDR1']
        ..collateralAddressMessages = ['message']
        ..collateralAddressSignatures = ['signature']
        ..regulated = true
        ..approvalServer = 'https://example.com/approval'
        ..approvalCriteria = 'Must pass KYC.';

      final result = InfoCurrency.from(currency);

      expect(result.code, 'USDC');
      expect(result.issuer,
          'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN');
      expect(result.codeTemplate, 'USD?');
      expect(result.status, 'live');
      expect(result.displayDecimals, 7);
      expect(result.name, 'USD Coin');
      expect(result.desc, 'A fully backed stablecoin.');
      expect(result.conditions, 'Subject to terms.');
      expect(result.image, 'https://example.com/usdc.png');
      expect(result.fixedNumber, 5);
      expect(result.maxNumber, 10);
      expect(result.isUnlimited, false);
      expect(result.isAssetAnchored, true);
      expect(result.anchorAssetType, 'fiat');
      expect(result.anchorAsset, 'USD');
      expect(result.attestationOfReserve, 'https://example.com/attest.pdf');
      expect(result.redemptionInstructions, 'Redeem at example.com.');
      expect(result.collateralAddresses, ['GADDR1']);
      expect(result.collateralAddressMessages, ['message']);
      expect(result.collateralAddressSignatures, ['signature']);
      expect(result.regulated, true);
      expect(result.approvalServer, 'https://example.com/approval');
      expect(result.approvalCriteria, 'Must pass KYC.');
    });

    test('assetId returns IssuedAssetId for a code/issuer pair', () {
      final currency = flutter_sdk.Currency()
        ..code = 'USDC'
        ..issuer = 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
      final result = InfoCurrency.from(currency);

      final assetId = result.assetId;
      expect(assetId, isA<IssuedAssetId>());
      final issued = assetId as IssuedAssetId;
      expect(issued.code, 'USDC');
      expect(issued.issuer,
          'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN');
      expect(issued.id,
          'USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN');
      expect(issued.sep38,
          'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN');
    });

    test('assetId returns NativeAssetId when code is "native" and issuer null', () {
      // The wallet SDK detects native assets purely by the literal code value.
      final currency = flutter_sdk.Currency()..code = 'native';
      final result = InfoCurrency.from(currency);

      expect(result.code, 'native');
      expect(result.issuer, isNull);
      expect(result.assetId, isA<NativeAssetId>());
      expect(result.assetId, equals(NativeAssetId()));
    });

    test('assetId throws ValidationException for code without issuer', () {
      final currency = flutter_sdk.Currency()..code = 'USDC';
      final result = InfoCurrency.from(currency);

      expect(() => result.assetId, throwsA(isA<ValidationException>()));
    });

    test('assetId throws ValidationException for issuer without code', () {
      final currency = flutter_sdk.Currency()
        ..issuer = 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
      final result = InfoCurrency.from(currency);

      expect(() => result.assetId, throwsA(isA<ValidationException>()));
    });

    test('assetId throws ValidationException when both code and issuer null', () {
      final result = InfoCurrency.from(flutter_sdk.Currency());
      expect(() => result.assetId, throwsA(isA<ValidationException>()));
    });

    test('assetId throws ValidationException when code is "native" with an issuer', () {
      // code == "native" is excluded from the issued-asset branch, and the
      // native branch requires a null issuer, so this pair is invalid.
      final currency = flutter_sdk.Currency()
        ..code = 'native'
        ..issuer = 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN';
      final result = InfoCurrency.from(currency);

      expect(() => result.assetId, throwsA(isA<ValidationException>()));
    });
  });

  group('Service DTO Tests', () {
    test('Sep6InfoData stores transferServer and optional anchorQuoteServer', () {
      final withQuote = Sep6InfoData('https://t.example.com',
          anchorQuoteServer: 'https://q.example.com');
      expect(withQuote.transferServer, 'https://t.example.com');
      expect(withQuote.anchorQuoteServer, 'https://q.example.com');

      final withoutQuote = Sep6InfoData('https://t.example.com');
      expect(withoutQuote.transferServer, 'https://t.example.com');
      expect(withoutQuote.anchorQuoteServer, isNull);
    });

    test('Sep10InfoData stores webAuthEndpoint and signingKey', () {
      final data = Sep10InfoData('https://auth.example.com', 'GSIGNINGKEY');
      expect(data.webAuthEndpoint, 'https://auth.example.com');
      expect(data.signingKey, 'GSIGNINGKEY');
    });

    test('Sep12InfoData stores kycServer and optional signingKey', () {
      final withKey = Sep12InfoData('https://kyc.example.com',
          signingKey: 'GSIGNINGKEY');
      expect(withKey.kycServer, 'https://kyc.example.com');
      expect(withKey.signingKey, 'GSIGNINGKEY');

      final withoutKey = Sep12InfoData('https://kyc.example.com');
      expect(withoutKey.kycServer, 'https://kyc.example.com');
      expect(withoutKey.signingKey, isNull);
    });

    test('Sep24InfoData stores transferServerSep24 and hasAuth', () {
      final data = Sep24InfoData('https://sep24.example.com', true);
      expect(data.transferServerSep24, 'https://sep24.example.com');
      expect(data.hasAuth, isTrue);

      final noAuth = Sep24InfoData('https://sep24.example.com', false);
      expect(noAuth.hasAuth, isFalse);
    });

    test('Sep31InfoData stores directPaymentServer, hasAuth and optionals', () {
      final full = Sep31InfoData('https://sep31.example.com', true,
          kycServer: 'https://kyc.example.com',
          anchorQuoteServer: 'https://q.example.com');
      expect(full.directPaymentServer, 'https://sep31.example.com');
      expect(full.hasAuth, isTrue);
      expect(full.kycServer, 'https://kyc.example.com');
      expect(full.anchorQuoteServer, 'https://q.example.com');

      final minimal = Sep31InfoData('https://sep31.example.com', false);
      expect(minimal.directPaymentServer, 'https://sep31.example.com');
      expect(minimal.hasAuth, isFalse);
      expect(minimal.kycServer, isNull);
      expect(minimal.anchorQuoteServer, isNull);
    });
  });
}
