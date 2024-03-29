@Timeout(const Duration(seconds: 400))

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;

import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  var wallet = Wallet.testNet;
  var stellar = wallet.stellar();
  var account = stellar.account();

  test('create account', () async {
    var accountKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(accountKeyPair.address);
    var newAccountKeyPair = account.createKeyPair();

    var txBuilder = await stellar.transaction(accountKeyPair);
    var tx = txBuilder
        .createAccount(newAccountKeyPair, startingBalance: "100.1")
        .build();
    stellar.sign(tx, accountKeyPair);
    bool success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var newAccount = await account.getInfo(newAccountKeyPair.address);
    assert(newAccount.sequenceNumber > 0);
    var balances = newAccount.balances;
    assert(balances.length == 1);
    assert(balances[0].assetType == 'native');
    assert(double.parse(balances[0].balance) == 100.1);
  });

  test('lock master key', () async {
    var accountKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(accountKeyPair.address);

    var txBuilder = await stellar.transaction(accountKeyPair);
    var tx = txBuilder.lockAccountMasterKey().build();
    stellar.sign(tx, accountKeyPair);
    bool success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var myAccount = await account.getInfo(accountKeyPair.address);
    var signers = myAccount.signers;
    assert(signers.length == 1);
    assert(signers[0].weight == 0);
  });

  test('add and remove new signer', () async {
    var accountKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(accountKeyPair.address);

    var txBuilder = await stellar.transaction(accountKeyPair);
    var newSignerKeyPair = account.createKeyPair();
    var tx = txBuilder.addAccountSigner(newSignerKeyPair, 11).build();
    stellar.sign(tx, accountKeyPair);
    bool success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var myAccount = await account.getInfo(accountKeyPair.address);
    var signers = myAccount.signers;
    assert(signers.length == 2);
    bool found = false;
    for (var signer in signers) {
      if (signer.weight == 11) {
        found = true;
        break;
      }
    }
    assert(found);

    // remove signer
    tx = txBuilder.removeAccountSigner(newSignerKeyPair).build();
    stellar.sign(tx, accountKeyPair);
    success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    myAccount = await account.getInfo(accountKeyPair.address);
    signers = myAccount.signers;
    assert(signers.length == 1);
    assert(signers[0].weight != 11);
  });

  test('set threshold', () async {
    var accountKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(accountKeyPair.address);

    var txBuilder = await stellar.transaction(accountKeyPair);
    var tx = txBuilder.setThreshold(low: 1, medium: 10, high: 20).build();
    stellar.sign(tx, accountKeyPair);
    bool success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var myAccount = await account.getInfo(accountKeyPair.address);
    assert(myAccount.thresholds.lowThreshold == 1);
    assert(myAccount.thresholds.medThreshold == 10);
    assert(myAccount.thresholds.highThreshold == 20);
  });

  test('add and remove asset support', () async {
    var accountKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(accountKeyPair.address);

    var asset = IssuedAssetId(
        code: "USDC",
        issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5");
    var txBuilder = await stellar.transaction(accountKeyPair);
    var tx = txBuilder.addAssetSupport(asset, limit: "100").build();
    stellar.sign(tx, accountKeyPair);
    bool success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var myAccount = await account.getInfo(accountKeyPair.address);
    assert(myAccount.balances.length == 2);
    bool found = false;
    for (var balance in myAccount.balances) {
      if (balance.assetCode == "USDC") {
        found = true;
        break;
      }
    }
    assert(found);

    // remove asset support
    txBuilder = await stellar.transaction(accountKeyPair);
    tx = txBuilder.removeAssetSupport(asset).build();
    stellar.sign(tx, accountKeyPair);
    success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    myAccount = await account.getInfo(accountKeyPair.address);
    assert(myAccount.balances.length == 1);
    assert(myAccount.balances[0].assetCode != "USDC");
  });

  Future<String> sendTransactionToBackend(String xdrString) async {
    // server signer src: https://replit.com/@crogobete/ServerSigner#main.py
    var serverSigner = DomainSigner("https://server-signer.replit.app/sign",
        requestHeaders: {"Authorization": "Bearer 987654321"});
    return await serverSigner.signWithDomainAccount(
        transactionXDR: xdrString,
        networkPassPhrase:
            wallet.stellarConfiguration.network.networkPassphrase);
  }

  test('building advanced transactions', () async {
    var externalKeyPair = PublicKeyPair.fromAccountId(
        "GBUTDNISXHXBMZE5I4U5INJTY376S5EW2AF4SQA2SWBXUXJY3OIZQHMV");
    var newKeyPair = account.createKeyPair();
    var txBuilder = await stellar.transaction(externalKeyPair);
    var createTxn =
        txBuilder.createAccount(newKeyPair, startingBalance: "10").build();
    var xdrString = createTxn.toEnvelopeXdrBase64();

    // Send xdr encoded transaction to your backend server to sign
    var xdrStringFromBackend = await sendTransactionToBackend(xdrString);

    // Decode xdr to get the signed transaction
    var signedTransaction = stellar.decodeTransaction(xdrStringFromBackend);

    // submit transaction to the network
    bool success = await stellar.submitTransaction(signedTransaction);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var newAccount = await account.getInfo(newKeyPair.address);
    assert(newAccount.sequenceNumber > 0);
    var balances = newAccount.balances;
    assert(balances.length == 1);
    assert(balances[0].assetType == 'native');
    assert(double.parse(balances[0].balance) == 10.0);

    // add device keypair
    var deviceKeyPair = account.createKeyPair();
    txBuilder = await stellar.transaction(newKeyPair);
    var modifyAccountTransaction = txBuilder
        .addAccountSigner(deviceKeyPair, 1)
        .lockAccountMasterKey()
        .build();
    stellar.sign(modifyAccountTransaction, newKeyPair);

    // submit transaction to the network
    success = await stellar.submitTransaction(modifyAccountTransaction);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    newAccount = await account.getInfo(newKeyPair.address);
    var signers = newAccount.signers;
    assert(signers.length == 2);
    bool deviceSignerFound = false;
    bool masterKeySignerFound = false;
    for (var signer in signers) {
      if (signer.accountId == deviceKeyPair.address) {
        assert(signer.weight == 1);
        deviceSignerFound = true;
      } else if (signer.accountId == newKeyPair.address) {
        assert(signer.weight == 0);
        masterKeySignerFound = true;
      } else {
        fail("should not have additional signers");
      }
    }
    assert(deviceSignerFound);
    assert(masterKeySignerFound);
  });

  test('sponsoring transactions', () async {
    var sponsorKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(sponsorKeyPair.address);

    var sponsoredKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(sponsoredKeyPair.address);

    var asset = IssuedAssetId(
        code: "USDC",
        issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5");

    var txBuilder = await stellar.transaction(sponsoredKeyPair);
    var tx = txBuilder
        .sponsoring(sponsorKeyPair, (builder) => builder.addAssetSupport(asset))
        .build();
    stellar.sign(tx, sponsorKeyPair);
    stellar.sign(tx, sponsoredKeyPair);

    bool success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var myAccount = await account.getInfo(sponsoredKeyPair.address);
    assert(myAccount.balances.length == 2);
    bool usdcFound = false;
    for (var balance in myAccount.balances) {
      if (balance.assetCode == "USDC") {
        assert(balance.sponsor == sponsorKeyPair.address);
        usdcFound = true;
      }
    }
    assert(usdcFound);
  });

  test('sponsoring account creation', () async {
    var sponsorKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(sponsorKeyPair.address);

    var newKeyPair = account.createKeyPair();

    var txBuilder = await stellar.transaction(sponsorKeyPair);
    var tx = txBuilder
        .sponsoring(
            sponsorKeyPair,
            sponsoredAccount: newKeyPair,
            (builder) => builder.createAccount(newKeyPair))
        .build();
    stellar.sign(tx, sponsorKeyPair);
    stellar.sign(tx, newKeyPair);

    bool success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var myAccount = await account.getInfo(newKeyPair.address);
    assert(myAccount.balances.length == 1);
    assert(double.parse(myAccount.balances[0].balance) == 0);
  });

  test('sponsoring account creation and modification', () async {
    var newKeyPair = account.createKeyPair();
    var replaceWith = account.createKeyPair();

    var sponsorKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(sponsorKeyPair.address);

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

    //print(tx.toEnvelopeXdrBase64());

    bool success = await stellar.submitTransaction(tx);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var myAccount = await account.getInfo(newKeyPair.address);
    assert(myAccount.balances.length == 1);
    assert(double.parse(myAccount.balances[0].balance) == 0);

    var signers = myAccount.signers;
    assert(signers.length == 2);
    bool replaceSignerFound = false;
    bool masterKeySignerFound = false;
    for (var signer in signers) {
      if (signer.accountId == replaceWith.address) {
        assert(signer.weight == 1);
        replaceSignerFound = true;
      } else if (signer.accountId == newKeyPair.address) {
        assert(signer.weight == 0);
        masterKeySignerFound = true;
      } else {
        fail("should not have additional signers");
      }
    }
    assert(replaceSignerFound);
    assert(masterKeySignerFound);
  });

  test('make fee bump', () async {
    var replaceWith = account.createKeyPair();

    var sponsorKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(sponsorKeyPair.address);

    var sponsoredKeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(sponsoredKeyPair.address);

    var txBuilder = await stellar.transaction(sponsoredKeyPair);
    var transaction = txBuilder
        .sponsoring(
            sponsorKeyPair,
            (builder) =>
                builder.lockAccountMasterKey().addAccountSigner(replaceWith, 1))
        .build();
    stellar.sign(transaction, sponsorKeyPair);
    stellar.sign(transaction, sponsoredKeyPair);

    var feeBump = stellar.makeFeeBump(sponsorKeyPair, transaction);
    stellar.sign(feeBump, sponsorKeyPair);

    bool success = await stellar.submitTransaction(feeBump);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var myAccount = await account.getInfo(sponsoredKeyPair.address);
    assert(myAccount.balances.length == 1);
    assert(double.parse(myAccount.balances[0].balance) == 10000.0);
    var signers = myAccount.signers;
    assert(signers.length == 2);
    bool newSignerFound = false;
    bool masterKeySignerFound = false;
    for (var signer in signers) {
      if (signer.accountId == replaceWith.address) {
        assert(signer.weight == 1);
        newSignerFound = true;
      } else if (signer.accountId == sponsoredKeyPair.address) {
        assert(signer.weight == 0);
        masterKeySignerFound = true;
      } else {
        fail("should not have additional signers");
      }
    }
    assert(newSignerFound);
    assert(masterKeySignerFound);
  });

  test('using XDR to send transaction data', () async {
    var sponsorKeyPair = PublicKeyPair.fromAccountId(
        "GBUTDNISXHXBMZE5I4U5INJTY376S5EW2AF4SQA2SWBXUXJY3OIZQHMV");
    var newKeyPair = account.createKeyPair();
    var txBuilder = await stellar.transaction(sponsorKeyPair);
    var sponsorAccountCreationTx = txBuilder
        .sponsoring(
            sponsorKeyPair, (builder) => builder.createAccount(newKeyPair),
            sponsoredAccount: newKeyPair)
        .build();
    stellar.sign(sponsorAccountCreationTx, newKeyPair);

    var xdrString = sponsorAccountCreationTx.toEnvelopeXdrBase64();

    // Send xdr encoded transaction to your backend server to sign
    var xdrStringFromBackend = await sendTransactionToBackend(xdrString);

    // Decode xdr to get the signed transaction
    var signedTransaction = stellar.decodeTransaction(xdrStringFromBackend);

    // submit transaction to the network
    bool success = await stellar.submitTransaction(signedTransaction);
    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var newAccount = await account.getInfo(newKeyPair.address);
    assert(newAccount.sequenceNumber > 0);
    var balances = newAccount.balances;
    assert(balances.length == 1);
    assert(balances[0].assetType == 'native');
    assert(double.parse(balances[0].balance) == 0.0);
  });

  test('submit transaction with fee increase', () async {
    var account1KeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(account1KeyPair.address);
    var account2KeyPair = account.createKeyPair();
    await flutter_sdk.FriendBot.fundTestAccount(account2KeyPair.address);

    // this test is more effective on public net
    // change wallet on top to: var wallet = Wallet.publicNet;
    // uncomment and fill:
    //var account1KeyPair = SigningKeyPair.fromSecret("S...");
    //var account2KeyPair = PublicKeyPair.fromAccountId("GBH5Y77GMEOCYQOXGAMJY4C65RAMBXKZBDHA5XBNLJQUC3Z2HGQP5OC5");

    bool success = await stellar.submitWithFeeIncrease(
        sourceAddress: account1KeyPair,
        timeout: const Duration(seconds: 30),
        baseFeeIncrease: 100,
        maxBaseFee: 2000,
        buildingFunction: (builder) =>
            builder.transfer(account2KeyPair.address, NativeAssetId(), "10.0"));

    assert(success);

    // wait for ledger
    await Future.delayed(const Duration(seconds: 5));

    // validate
    var newAccount = await account.getInfo(account2KeyPair.address);
    assert(newAccount.sequenceNumber > 0);
    var balances = newAccount.balances;
    assert(balances.length == 1);
    assert(balances[0].assetType == 'native');
    assert(double.parse(balances[0].balance) == 10010.0);

    var server = stellar.server;
    var transactions =
        await server.transactions.forAccount(newAccount.accountId).execute();
    assert(transactions.records != null);
    assert(transactions.records!.length == 2);
    /*for (var tx in transactions.records!) {
      print(tx.hash);
    }*/
  });
}
