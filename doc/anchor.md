
# Anchor

Build on and off ramps with anchors for deposits and withdrawals:

```dart
Anchor anchor = wallet.anchor("testanchor.stellar.org");
```

Get anchor information from a TOML file  using [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md):

```dart
TomlInfo tomlInfo = await anchor.getInfo();
```

Upload KYC information to anchors using [SEP-012](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md):

```dart
Sep12 sep12 = await anchor.sep12();
AddCustomerResponse addResponse = await sep12.add({"account_id" : accountId});
```

Authenticate an account with the anchor using [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md):

```dart
Sep10 sep10 = await anchor.sep10();
AuthToken authToken = await sep10.authenticate(accountKeyPair);
```

Available anchor services and information about them. For example, interactive deposit/withdrawal limits, currency, fees, payment methods
using [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md):

```dart
AnchorServiceInfo serviceInfo = await anchor.sep24().getServiceInfo();
```

Interactive deposit and withdrawal using [SEP-024](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md):

```dart
String interactiveUrl = (await anchor.sep24().deposit(asset, authToken)).url;
```

```dart
String interactiveUrl = (await anchor.sep24().withdraw(asset, authToken)).url;
```

Deposit with extra [SEP-009](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md) fields and/or files:

```dart
Map<String, String> sep9Fields = {"email_address": "mail@example.com"};

Uint8List photoIdFront = await Util.readFile(path);
Map<String, Uint8List> sep9Files = {"photo_id_front": photoIdFront};

InteractiveFlowResponse response = await anchor.sep24().deposit(
    asset, authToken, extraFields: sep9Fields, extraFiles: sep9Files);

String interactiveUrl = response.url;
```

Deposit with alternative account:
```dart
String recepientAccountId = "G...";
InteractiveFlowResponse response = await anchor.sep24().deposit(asset, 
    authToken, destinationAccount: recepientAccountId);
```

Get single transaction's current status and details:
```dart
AnchorTransaction transaction = await anchor.sep24().getTransaction("12345", authToken);
```

Get account transactions for specified asset:
```dart
List<AnchorTransaction> transactions = await anchor.sep24().getHistory(asset, authToken);
```

Watch transaction:

```dart
Watcher watcher = anchor.sep24.watcher();
WatcherResult result = watcher.watchOneTransaction(token, "transaction id");

result.controller.stream.listen(
  (event) {
    if (event is StatusChange) {
      print("Status changed to ${event.status}. Transaction: ${event.transaction.id}");
    } else if (event is ExceptionHandlerExit) {
      print("Exception handler exited the job");
    } else if (event is StreamControllerClosed) {
      print("Stream controller closed. Job is done");
    }
  }
);
```

Watch asset:

```dart
Watcher watcher = anchor.sep24.watcher();
WatcherResult result = watcher.watchAsset(token, asset);

result.controller.stream.listen(
  (event) {
    if (event is StatusChange) {
      print("Status changed to ${event.status}. Transaction: ${event.transaction.id}");
    } else if (event is ExceptionHandlerExit) {
      print("Exception handler exited the job");
    } else if (event is StreamControllerClosed) {
      print("Stream controller closed. Job is done");
    }
  }
);
```

A full SEP-024 example can be found in the project folder. To start it, navigate to `cd example` and run `flutter run`.

## Add client domain signing

Supporting `client_domain` comes in two parts, the wallet's client and the wallet's server implementations. 
In this setup, we will have an extra authentication key. This key will be stored remotely on the server. 
Using the [SEP-010](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md) info file, 
the anchor will be able to query this key and verify the signature. As such, the anchor would be able to confirm
that the request is coming from your wallet, belonging to wallet's `client_domain`.

### Client Side

First, let's implement the client side. In this example we will connect to a remote signer that 
signs transactions on the endpoint `https://demo-wallet-server.stellar.org/sign` for the client `domain demo-wallet-server.stellar.org`.

```dart
DomainSigner signer = DomainSigner("https://demo-wallet-server.stellar.org/sign");
Sep10 sep10 = await anchor.sep10();

AuthToken authToken = await sep10.authenticate(userKeyPair,
    clientDomainSigner: signer, clientDomain: "demo-wallet-server.stellar.org");
```

Danger: The demo-wallet signing endpoint is not protected for anybody to use. Your production URL must be protected, otherwise anybody could impersonate your wallet's user.

Let's add authentication with a bearer token. Simply pass the needed request headers with your token:

```dart
Map<String, String> requestHeaders = {
  "Authorization": "Bearer $token",
  "Content-Type": "application/json"
};

DomainSigner signer = DomainSigner("https://demo-wallet-server.stellar.org/sign",
    requestHeaders: requestHeaders);
```
### Server Side

Next, let's implement the server side.

First, generate a new authentication key that will be used as a `client_domain` authentication key.

Next, create a [SEP-001](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md)
`toml` file placed under `<your domain>/.well-known/stellar.toml` with the following content:

````toml
ACCOUNTS = [ "Authentication public key (address)" ]
VERSION = "0.1.0"
SIGNING_KEY = "Authentication public key (address)"
NETWORK_PASSPHRASE = "Test SDF Network ; September 2015"
````

Don't forget to change the network passphrase for Mainnet deployment.

Finally, let's add a server implementation. This sample implementation uses express framework:

```javascript
app.post("/sign", (req, res) => {
  const envelope_xdr = req.body.transaction;
  const network_passphrase = req.body.network_passphrase;
  const transaction = new Transaction(envelope_xdr, network_passphrase);

  if (Number.parseInt(transaction.sequence, 10) !== 0) {
    res.status(400);
    res.send("transaction sequence value must be '0'");
    return;
  }

  transaction.sign(Keypair.fromSecret(SERVER_SIGNING_KEY));

  res.set("Access-Control-Allow-Origin", "*");
  res.status(200);
  res.send({
    transaction: transaction.toEnvelope().toXDR("base64"),
    network_passphrase: network_passphrase,
  });
});
```

The `DomainSigner` will request remote signing at the given endpoint by posting a request that contains a json with 
the `transaction` and `network_passphrase`. On the server side you can now sign the transaction with the client
keypair and send it back as a result. As mentioned before, this sample implementation doesn't have any protection
against unauthorized requests, so you must add authorization checks as part of the request.
