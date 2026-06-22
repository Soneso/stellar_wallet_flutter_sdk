import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

import '../activity_log.dart';

Future<void> runExample() async {
  final wallet = Wallet.testNet;
  final anchor = wallet.anchor("testanchor.stellar.org");

  // Get sep-001 info from the anchor server
  // This will parse the stellar toml data from
  // https://testanchor.stellar.org/.well-known/stellar.toml

  final info = await anchor.getInfo();
  logLine("Accounts: ${info.accounts}");
  logLine("Signing key: ${info.signingKey}");
  logLine("Network passphrase: ${info.networkPassphrase}");

  logLine("_____________________");
  logLine("Transfer server (sep-006): ${info.transferServer}");
  logLine("Transfer server (sep-024): ${info.transferServerSep24}");
  logLine("Webauth endpoint (sep-010): ${info.webAuthEndpoint}");
  logLine("KYC server (sep-012): ${info.kycServer}");
  logLine("Direct payment server (sep-031): ${info.directPaymentServer}");
  logLine("Anchor quote server (sep-038): ${info.anchorQuoteServer}");

  final currencies = info.currencies;
  if (currencies != null) {
    for (var currency in currencies) {
      logLine("_____________________");
      logLine("Currency:  ${currency.code}:${currency.issuer}");
      logLine("Description: ${currency.desc}");
      logLine("Status:  ${currency.status}");
      logLine("Is anchored: ${currency.isAssetAnchored}");
    }
  }

  logLine("_____________________");
  logLine("Documentation");
  logLine("Organization: ${info.documentation?.orgName}");
  logLine("Url: ${info.documentation?.orgUrl}");
  logLine("Description: ${info.documentation?.orgDescription}");
  logLine("GitHub: ${info.documentation?.orgGithub}");
}
