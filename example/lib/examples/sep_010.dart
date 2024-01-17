import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

Future<void> runExample() async {
  final wallet = Wallet.testNet;
  const anchorDomain = "testanchor.stellar.org";
  final anchor = wallet.anchor(anchorDomain);

  // Get info from the anchor server
  final info = await anchor.getInfo();
  print("SEP 10 web auth endpoint: ${info.webAuthEndpoint}");

  // Prepare a new user account for this example.
  final userKeyPair = wallet.stellar().account().createKeyPair();

  // Basic Authentication
  final sep10 = await anchor.sep10();
  var authToken = await sep10.authenticate(userKeyPair);
  print("Basic Authentication JWT: " + authToken.jwt);

  // With Memo
  authToken = await sep10.authenticate(userKeyPair, memoId: 123);
  print("Basic Authentication with Memo JWT: " + authToken.jwt);

  // With client domain signer
  // client domain signer src: https://replit.com/@crogobete/ClientDomainSigner#main.py
  const clientDomainSignerUrl = "https://client-domain-signer.replit.app/sign";
  const clientDomain = "client-domain-signer.replit.app";

  var clientDomainSigner = DomainSigner(clientDomainSignerUrl,
      requestHeaders: {"Authorization": "Bearer 123456789"});

  authToken = await sep10.authenticate(userKeyPair,
      clientDomainSigner: clientDomainSigner, clientDomain: clientDomain);
  print("Client Domain Signer JWT: " + authToken.jwt);
}
