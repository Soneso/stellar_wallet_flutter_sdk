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
  // Remote signer source code: https://github.com/Soneso/go-server-signer
  const clientDomainSignerUrl = "https://testsigner.stellargate.com/sign-sep-10";
  const clientDomain = "testsigner.stellargate.com";

  var clientDomainSigner = DomainSigner(clientDomainSignerUrl,
      requestHeaders: {"Authorization": "Bearer 7b23fe8428e7fb9b3335ed36c39fb5649d3cd7361af8bf88c2554d62e8ca3017"});

  authToken = await sep10.authenticate(userKeyPair,
      clientDomainSigner: clientDomainSigner, clientDomain: clientDomain);
  print("Client Domain Signer JWT: " + authToken.jwt);
}
