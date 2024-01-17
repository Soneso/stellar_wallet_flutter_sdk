# Stellar Network

In the previous section we learned how to create a wallet and a Stellar object that provides a connection to Horizon. In this section, we will look at the usages of this class.

## Accounts

The most basic entity on the Stellar network is an account. Let's look into AccountService that provides the capability to work with accounts:

```dart
var account = wallet.stellar().account();
```

Now we can create a keypair:

```dart
var accountKeyPair = account.createKeyPair();
```

## Build transaction

The transaction builder allows you to create various transactions that can be signed and submitted to the Stellar network. Some transactions can be sponsored.

### Building Basic Transactions
First, let's look into building basic transactions.

#### Create Account

The create account transaction activates/creates an account with a starting balance of XLM (1 XLM by default).

```dart
var txBuilder = await stellar.transaction(sourceAccountKeyPair);
var tx = txBuilder.createAccount(destinationAccountKeyPair).build();
```

#### Modify Account

You can lock the master key of the account by setting its weight to 0. Use caution when locking the account's master key. Make sure you have set the correct signers and weights. Otherwise, you will lock the account irreversibly.

```dart
var txBuilder = await stellar.transaction(sourceAccountKeyPair);
var tx = txBuilder.lockAccountMasterKey().build();
```

Add a new signer to the account. Use caution when adding new signers and make sure you set the correct signer weight. Otherwise, you will lock the account irreversibly.

```dart
var txBuilder = await stellar.transaction(sourceAccountKeyPair);
var tx = txBuilder.addAccountSigner(newSignerKeyPair, 10).build();
```

Remove a signer from the account.

```dart
var txBuilder = await stellar.transaction(sourceAccountKeyPair);
var tx = txBuilder.removeAccountSigner(newSignerKeyPair).build();
```

Modify account thresholds (useful when multiple signers are assigned to the account). This allows you to restrict access to certain operations when the limit is not reached.

```dart
var txBuilder = await stellar.transaction(sourceAccountKeyPair);
var tx = txBuilder.setThreshold(low: 1, medium: 10, high: 20).build();
```

#### Modify Assets (Trustlines)

Add an asset (trustline) to the account. This allows the account to receive transfers of the asset.

```dart
var asset = IssuedAssetId(code: "USDC", issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5");
var txBuilder = await stellar.transaction(sourceAccountKeyPair);
txBuilder.addAssetSupport(asset).build();
```

Remove an asset from the account (the asset's balance must be 0).

```dart
var asset = IssuedAssetId(code: "USDC", issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5");
var txBuilder = await stellar.transaction(sourceAccountKeyPair);
txBuilder.removeAssetSupport(asset).build();
```

#### Building Advanced Transactions

In some cases a private key may not be known prior to forming a transaction. For example, a new account must be funded to exist and the wallet may not have the key for the account so may request the create account transaction to be sponsored by a third party.

```dart
var externalKeyPair = PublicKeyPair.fromAccountId("G...");
var newKeyPair = account.createKeyPair();
```
First, the account must be created.


```dart
var txBuilder = await stellar.transaction(externalKeyPair);
var createTxn = txBuilder.createAccount(newKeyPair).build();
```
This transaction must be sent to external signer (holder of externalKeyPair) to be signed.

```dart
var xdrString = createTxn.toEnvelopeXdrBase64();

// Send xdr encoded transaction to your backend server to sign
var xdrStringFromBackend = await sendTransactionToBackend(xdrString);

// Decode xdr to get the signed transaction
var signedTransaction = stellar.decodeTransaction(xdrStringFromBackend);
```

You can read more about passing XDR transaction to the server in the chapter below.

Signed transaction can be submitted by the wallet.

```dart
bool success = await stellar.submitTransaction(signedTransaction);
```

Now, after the account is created, it can perform operations. For example, we can disable the master keypair and replace it with a new one (let's call it the device keypair) atomically in one transaction:

```dart
var deviceKeyPair = account.createKeyPair();

var txBuilder = await stellar.transaction(newKeyPair);
var modifyAccountTransaction = txBuilder
    .addAccountSigner(deviceKeyPair, 1)
    .lockAccountMasterKey()
    .build();

stellar.sign(modifyAccountTransaction, newKeyPair);

// submit transaction to the network
success = await stellar.submitTransaction(modifyAccountTransaction);
```

#### Sponsoring Transactions

##### Sponsoring Operations

Some operations, that modify account reserves can be [sponsored](https://developers.stellar.org/docs/encyclopedia/sponsored-reserves#sponsored-reserves-operations). For sponsored operations, the sponsoring account will be paying for the reserves instead of the account that being sponsored. This allows you to do some operations, even if account doesn't have enough funds to perform such operations. To sponsor a transaction, simply start a sponsoring block:

```dart
var txBuilder = await stellar.transaction(sponsoredKeyPair);
var tx = txBuilder
    .sponsoring(sponsorKeyPair, (builder) => builder.addAssetSupport(asset))
    .build();
stellar.sign(tx, sponsorKeyPair);
stellar.sign(tx, sponsoredKeyPair);
```

Info:
Only some operations can be sponsored, and a sponsoring builder has a slightly different set of functions available compared to the regular TxBuilder. Note, that a transaction must be signed by both the sponsor account (`sponsoringKeyPair`) and the account being sponsored (`sponsoredKeyPair`).

##### Sponsoring Account Creation

One of the things that can be done via sponsoring is to create an account with a 0 starting balance. This account creation can be created by simply writing:

```dart
var newKeyPair = account.createKeyPair();

var txBuilder = await stellar.transaction(sponsorKeyPair);
var tx = txBuilder
    .sponsoring(sponsorKeyPair, sponsoredAccount: newKeyPair,
        (builder) => builder.createAccount(newKeyPair))
    .build();

stellar.sign(tx, sponsorKeyPair);
stellar.sign(tx, newKeyPair);
```
Note how in the first example the transaction source account is set to `sponsoredKeyPair`. Due to this, we did not need to pass a sponsored account value to the sponsoring function. Since when ommitted, the sponsored account defaults to the transaction source account (`sponsoredKeyPair`).

However, this time, the sponsored account (freshly created `newKeyPair`) is different from the transaction source account. Therefore, it's necessary to specify it. Otherwise, the transaction will contain a malformed operation. As before, the transaction must be signed by both keys.

##### Sponsoring Account Creation and Modification

If you want to create an account and modify it in one transaction, it's possible to do so with passing a `sponsoredAccount` optional argument to the sponsored function (`newKeyPair` below). If this argument is present, all operations inside the sponsored function will be sourced by this `sponsoredAccount`. (Except account creation, which is always sourced by the sponsor).

```dart
var newKeyPair = account.createKeyPair();
var replaceWith = account.createKeyPair();

var txBuilder = await stellar.transaction(sponsorKeyPair);
var tx = txBuilder
    .sponsoring(
    sponsorKeyPair,
    sponsoredAccount: newKeyPair,
        (builder) => builder
        .createAccount(newKeyPair)
        .addAccountSigner(replaceWith, 1)
        .lockAccountMasterKey())
    .build();

stellar.sign(tx, sponsorKeyPair);
stellar.sign(tx, newKeyPair);
```

#### Fee-Bump Transaction

If you wish to modify a newly created account with a 0 balance, it's also possible to do so via `FeeBump`. It can be combined with a sponsoring block to achieve the same result as in the example above. However, with `FeeBump` it's also possible to add more operations (that don't require sponsoring), such as a transfer.

First, let's create a transaction that will replace the master key of an account with a new keypair.

```dart
var replaceWith = account.createKeyPair();

var txBuilder = await stellar.transaction(sponsoredKeyPair);
var transaction = txBuilder
    .sponsoring(sponsorKeyPair,
        (builder) => builder.lockAccountMasterKey().addAccountSigner(replaceWith, 1))
    .build();
```

Second, sign transaction with both keys.

```dart
stellar.sign(transaction, sponsorKeyPair);
stellar.sign(transaction, sponsoredKeyPair);
```

Next, create a fee bump, targeting the transaction.

```dart
var feeBump = stellar.makeFeeBump(sponsorKeyPair, transaction);
stellar.sign(feeBump, sponsorKeyPair);
```

Finally, submit a fee-bump transaction. Executing this transaction will be fully covered by the `sponsorKeyPair` and `sponsoredKeyPair` and may not even have any XLM funds on its account.

```dart
bool success = await stellar.submitTransaction(feeBump);
```
#### Using XDR to Send Transaction Data

Note, that a wallet may not have a signing key for `sponsorKeyPair`. In that case, it's necessary to convert the transaction to XDR, send it to the server, containing `sponsorKey` and return the signed transaction back to the wallet. Let's use the previous example of sponsoring account creation, but this time with the sponsor key being unknown to the wallet. The first step is to define the public key of the sponsor keypair:

```dart
var sponsorKeyPair = PublicKeyPair.fromAccountId("G...");
```

Next, create an account in the same manner as before and sign it with `newKeyPair`. This time, convert the transaction to XDR:

```dart
var newKeyPair = account.createKeyPair();
var txBuilder = await stellar.transaction(sponsorKeyPair);
var sponsorAccountCreationTx = txBuilder
    .sponsoring(
        sponsorKeyPair, (builder) => builder.createAccount(newKeyPair),
        sponsoredAccount: newKeyPair)
    .build();

stellar.sign(sponsorAccountCreationTx, newKeyPair);

var xdrString = sponsorAccountCreationTx.toEnvelopeXdrBase64();
```

It can now be sent to the server. On the server, sign it with a private key for the sponsor address:

```dart
String signTransaction(String xdrString) {
  var sponsorPrivateKey = SigningKeyPair.fromSecret("MySecret");
  
  var transaction = stellar.decodeTransaction(xdrString);
  stellar.sign(transaction, sponsorPrivateKey);
  
  return transaction.toEnvelopeXdrBase64();
}
```

When the client receives the fully signed transaction, it can be decoded and sent to the Stellar network:

```dart
var signedTransaction = stellar.decodeTransaction(xdrStringFromBackend);

bool success = await stellar.submitTransaction(signedTransaction);
```

### Submit Transaction

Info:
It's strongly recommended to use the wallet SDK transaction submission functions instead of Horizon alternatives. The wallet SDK gracefully handles timeout and out-of-fee exceptions.

Finally, let's submit a signed transaction to the Stellar network. Note that a sponsored transaction must be signed by both the account and the sponsor.

The transaction is automatically re-submitted on the Horizon 504 error (timeout), which indicates a sudden network activity increase.

```dart
stellar.sign(transaction, sourceAccountKeyPair);

bool success = await stellar.submitTransaction(transaction);
```

However, the method above doesn't handle fee surge pricing in the network gracefully. If the required fee for a transaction to be included in the ledger becomes too high and transaction expires before making it into the ledger, this method will throw an exception.

So, instead, the alternative approach is to:

```dart
bool success = await stellar.submitWithFeeIncrease(
    sourceAddress: sourceAccountKeyPair,
    timeout: const Duration(seconds: 30),
    baseFeeIncrease: 100,
    maxBaseFee: 2000,
    buildingFunction: (builder) =>
    builder.transfer(destinationAccountKeyPair.address, NativeAssetId(), "10.0"));
```

This will create and sign the transaction that originated from the sourceAccountKeyPair. Every 30 seconds this function will re-construct this transaction with a new fee (increased by 100 stroops), repeating signing and submitting. Once the transaction is successful, the function will return the transaction body. Note, that any other error will terminate the retry cycle and an exception will be thrown.

### Accessing Flutter Stellar SDK

It's very simple to use the Flutter Stellar SDK connecting to the same Horizon instance as a Wallet class. To do so, simply call:

```dart
var server = stellar.server;
var transactions = await server.transactions.forAccount(newAccount.accountId).execute();
```

### Further readings

The Flutter Wallet SDK contains different test cases where you can find the above described functionality as working examples and more. You can find the stellar test cases [here](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/test/stellar_test.dart). 
