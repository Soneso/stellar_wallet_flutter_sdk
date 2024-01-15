import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

Future<void> runExample() async {
  final wallet = Wallet(StellarConfiguration.testNet);
  const anchorDomain = "testanchor.stellar.org";
  final anchor = wallet.anchor(anchorDomain);

  // Get sep-001 info from the anchor server
  // This will parse the stellar toml data from
  // https://testanchor.stellar.org/.well-known/stellar.toml

  final info = await anchor.getInfo();
  print("Accounts: ${info.accounts}");
  print("Signing key: ${info.signingKey}");
  print("Network passphrase: ${info.networkPassphrase}");

  print("_____________________");
  print("Transfer server (sep-006): ${info.transferServer}");
  print("Transfer server (sep-024): ${info.transferServerSep24}");
  print("Webauth endpoint (sep-010): ${info.webAuthEndpoint}");
  print("KYC server (sep-012): ${info.kycServer}");
  print("Direct payment server (sep-031): ${info.directPaymentServer}");
  print("Anchor quote server (sep-038): ${info.anchorQuoteServer}");

  final currencies = info.currencies;
  if (currencies != null) {
    for (var currency in currencies) {
      print("_____________________");
      print("Currency:  ${currency.code}:${currency.issuer}");
      print("Description: ${currency.desc}");
      print("Status:  ${currency.status}");
      print("Is anchored: ${currency.isAssetAnchored}");
    }
  }

  print("_____________________");
  print("Documentation");
  print("Organization: ${info.documentation?.orgName}");
  print("Url: ${info.documentation?.orgUrl}");
  print("Description: ${info.documentation?.orgDescription}");
  print("GitHub: ${info.documentation?.orgGithub}");
}
