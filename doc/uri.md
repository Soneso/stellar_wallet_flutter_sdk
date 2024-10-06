# URI Scheme to facilitate delegated signing

The [SEP-07](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md) standard defines a way for a non-wallet application to construct a URI scheme that represents a specific transaction for an account to sign. The scheme used is `web+stellar`, followed by a colon. Example: `web+stellar:<operation>?<param1>=<value1>&<param2>=<value2>`

## Tx Operation

The tx operation represents a request to sign a specific transaction envelope, with [some configurable parameters](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0007.md#operation-tx).

```dart
final sourceAccountKeyPair = PublicKeyPair.fromAccountId('G...');
final destinationAccountKeyPair = PublicKeyPair.fromAccountId('G...');
var txBuilder = await stellar.transaction(sourceAccountKeyPair);
final tx = txBuilder.createAccount(destinationAccountKeyPair).build();
final xdr = Uri.encodeComponent(tx.toEnvelopeXdrBase64());
final callback = Uri.encodeComponent('https://example.com/callback');
final txUri = 'web+stellar:tx?xdr=$xdr&callback=$callback';
final uri = wallet.parseSep7Uri(txUri);
// uri can be parsed and transaction can be signed/submitted by an application that implements Sep-7
```

You can set replacements to be made in the xdr for specific fields by the application, these will be added in [the Sep-11 transaction representation format](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0011.md) to the URI.

```dart
final uri = wallet.parseSep7Uri(txUri);

if (uri is Sep7Tx) {
    uri.addReplacement(Sep7Replacement(
        id: 'X',
        path: 'sourceAccount',
        hint: 'account from where you want to pay fees'));
}
```

You can assign parameters after creating the initial instance using the appropriate setter for the parameter.

```dart
final sourceAccountKeyPair = PublicKeyPair.fromAccountId('G...');
final destinationAccountKeyPair = PublicKeyPair.fromAccountId('G...');
var txBuilder = await stellar.transaction(sourceAccountKeyPair);
final tx = txBuilder.createAccount(destinationAccountKeyPair).build();

final uri = Sep7Tx.forTransaction(tx);
uri.setCallback('https://example.com/callback');
uri.setMsg('here goes a message');
uri.toString(); // encodes everything and converts to a uri string
```

## Pay Operation

The pay operation represents a request to pay a specific address with a specific asset, regardless of the source asset used by the payer. You can configure parameters to build the payment operation.

```dart
const destination = 'G...';
const assetIssuer = 'G...';
const assetCode = 'USDC';
const amount = '120.1234567';
const memo = 'memo';
final message = Uri.encodeComponent('pay me with lumens');
const originDomain = 'example.com';
final payUri = 'web+stellar:pay?destination=$destination&amount=$amount&memo=$memo&msg=$message&origin_domain=$originDomain&asset_issuer=$assetIssuer&asset_code=$assetCode';
final uri = Sep7.parseSep7Uri(payUri);
// uri can be parsed and transaction can be built/signed/submitted by an application that implements Sep-7
```

You can assign parameters after creating the initial instance using the appropriate setter for the parameter.

```dart
final uri = Sep7Pay.forDestination('G...');
uri.setCallback('https://example.com/callback');
uri.setMsg('here goes a message');
uri.setAssetCode('USDC');
uri.setAssetIssuer('G...');
uri.setAmount('10');
uri.toString(); // encodes everything and converts to a uri string
```
The last step after building a `Sep7Tx` or `Sep7Pay` is to add a signature to your uri. This will create a payload out of the transaction and sign it with the provided keypair.

```dart
final uri = Sep7Pay.forDestination('G...');
uri.setOriginDomain('example.com');
final keypair = wallet.stellar().account().createKeyPair();
uri.addSignature(keypair);
print(uri.getSignature()); // signed uri payload
```

The signature can then be verified by fetching the [Stellar toml file](https://developers.stellar.org/docs/build/apps/example-application-tutorial/anchor-integration/sep1) from the origin domain in the uri, and using the included signing key to verify the uri signature. This is all done as part of the `verifySignature` method.

```dart
final passesVerification = await uri.verifySignature(); // true or false
```

## Further readings

Multiple examples can be found in the [SEP-07 test cases](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/test/uri_test.dart)