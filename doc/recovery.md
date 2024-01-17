
# Recovery

The [SEP-030](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md) standard defines 
the standard way for an individual (e.g., a user or wallet) to regain access to their Stellar account after losing
its private key without providing any third party control of the account. During this flow the wallet communicates 
with one or more recovery signer servers to register the wallet for a later recovery if it's needed.

## Create Recoverable Account

First, let's create an account key, a device key, and a recovery key that will be attached to the account.

```dart
var accountKp = wallet.stellar().account().createKeyPair();
var deviceKp = wallet.stellar().account().createKeyPair();
var recoveryKp = wallet.stellar().account().createKeyPair();
```
The `accountKp` is the wallet's main account. The `deviceKp` we will be adding to the wallet as a signer so a device (eg. a mobile device a wallet is hosted on) can take control of the account. 
And the `recoveryKp` will be used to identify the key with the recovery servers.

Next, let's identify the recovery servers and create our recovery object:

```dart
var first = RecoveryServerKey("first");
var second = RecoveryServerKey("second");
var firstServer = RecoveryServer("https://recovery.example1.com", "https://auth.example1.com", "recovery.example1.com");
var secondServer = RecoveryServer("https://recovery.example2.com", "https://auth.example2.com", "recovery.example2.com");
var servers = {first:firstServer, second:secondServer};
var recovery = wallet.recovery(servers);
```

Next, we need to define SEP-30 identities. In this example we are going to create an identity for both servers. Registering an identity tells the recovery server what identities are allowed to access the account.

```dart
  var identity1 = [
    RecoveryAccountIdentity(RecoveryRole.owner, [
      RecoveryAccountAuthMethod(RecoveryType.stellarAddress, recoveryKp.address)
    ])
  ];

  var identity2 = [
    RecoveryAccountIdentity(RecoveryRole.owner,
        [RecoveryAccountAuthMethod(RecoveryType.email, "my-email@example.com")])
  ];
```

Here, stellar key and email are used as recovery methods. Other recovery servers may support phone as a recovery method as well.

You can read more about SEP-30 identities [here](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0030.md#common-request-fields)

Next, let's create a recoverable account:

```dart
var recoverableWallet = await recovery.createRecoverableWallet(
    RecoverableWalletConfig(
        accountKp,
        deviceKp,
        AccountThreshold(10, 10, 10),
        {first: identity1, second: identity2},
        SignerWeight(10, 5)
    )
);
```

With the given parameters, this function will create a transaction that will:

1. Set `deviceKp` as the primary account key. Please note that the master key belonging to `accountKp` will be locked. deviceKp should be used as a primary signer instead.
2. Set all operation thresholds to 10. You can read more about threshold in the [documentation](https://developers.stellar.org/docs/encyclopedia/signatures-multisig#thresholds)
3. Use identities that were defined earlier on both servers. (That means, both server will accept SEP-10 authentication via `recoveryKp` as an auth method)
4. Set device key weight to 10, and recovery server weight to 5. Given these account thresholds, both servers must be used to recover the account, as transaction signed by one will only have weight of 5, which is not sufficient to change account key.

Note: You can also provide a sponsor for the transaction.

Finally, sign and submit transaction to the network:

```dart
var transaction = recoverableWallet.transaction;
transaction.sign(accountKp.keyPair, flutter_sdk.Network.TESTNET);
await wallet.stellar().submitTransaction(transaction);
```

## Get Account Info

You can fetch account info from one or more servers. To do so, first we need to authenticate with a recovery server using the SEP-10 authentication method:

```dart
var sep10 = await recovery.sep10Auth(first);
var authToken = await sep10.authenticate(recoveryKp);
```

Next, get account info using auth tokens:

```dart
var accountInfo = await recovery.getAccountInfo(accountKp, {first: authToken.jwt});
```

Our second identity uses an email as an auth method. For that we can't use a [SEP-10] auth token for that server. Instead we need to use a token that ties the email to the user. For example, Firebase tokens are a good use case for this. To use this, the recovery signer server needs to be prepared to handle these kinds of tokens.

Getting account info using these tokens is the same as before.

```dart
var accountInfo = await recovery.getAccountInfo(accountKp, {second: <other token string>});
```

## Recover Wallet

Let's say we've lost our device key and need to recover our wallet.

First, we need to authenticate with both recovery servers:

```dart
var sep10 = await recovery.sep10Auth(first);
var authToken = await sep10.authenticate(recoveryKp);

var auth1 = authToken.jwt;
var auth2 = "..."; // get other token e.g. firebase token
```

We need to know the recovery signer addresses that will be used to sign the transaction. You can get them from either the recoverable wallet object we created earlier (`recoverableWallet.signers`), or via fetching account info from recovery servers.

```dart
var recoverySigners = recoverableWallet.signers;
```

Next, create a new device key and retrieve a signed transaction that replaces the device key:

```dart
var newKey = wallet.stellar().account().createKeyPair();
var serverAuth = {
  first: RecoveryServerSigning(recoverySigners[0], auth1),
  second: RecoveryServerSigning(recoverySigners[1], auth2)
};

var signedReplaceKeyTx = await recovery.replaceDeviceKey(accountKp, newKey, serverAuth);
```

Calling this function will create a transaction that locks the previous device key and replaces it with your new key (having the same weight as the old one). Both recovery signers will have signed the transaction.

The lost device key is deduced automatically if not given. A signer will be considered a device key, if one of these conditions matches:

1. It's the only signer that's not in `serverAuth`. 
2. All signers in `serverAuth` have the same weight, and the potential signer is the only one with a different weight.

3. Note that the account created above will match the first criteria. If 2-3 schema were used, then second criteria would match. (In 2-3 schema, 3 serves are used and 2 of them is enough to recover key. This is a recommended approach.)

Note: By using the `replaceDeviceKey` function you can also provide the lost key and you can also provide a sponsor for the transaction.
Note: You can also use a more low-level `signWithRecoveryServers` function to sign arbitrary transaction.

Finally, it's time to submit the transaction:

```dart
await wallet.stellar().submitTransaction(signedReplaceKeyTx));
```

## Further readings
The [recovery test cases](https://github.com/Soneso/stellar_wallet_flutter_sdk/blob/main/test/recovery_test.dart) contain many examples that can be used to learn more about the recovery service.
