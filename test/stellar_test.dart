@Timeout(Duration(seconds: 400))

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;

import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

void main() {
  var wallet = Wallet.testNet;
  var stellar = wallet.stellar();
  var account = stellar.account();

  test('create account', () async {
    var accountKeyPair = account.createKeyPair();
    await stellar.fundTestNetAccount(accountKeyPair.address);

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
    assert(newAccount.sequenceNumber > BigInt.zero);
    var balances = newAccount.balances;
    assert(balances.length == 1);
    assert(balances[0].assetType == 'native');
    assert(double.parse(balances[0].balance) == 100.1);
  });

  test('lock master key', () async {
    var accountKeyPair = account.createKeyPair();
    await stellar.fundTestNetAccount(accountKeyPair.address);

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
    await stellar.fundTestNetAccount(accountKeyPair.address);

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
    await stellar.fundTestNetAccount(accountKeyPair.address);

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
    await stellar.fundTestNetAccount(accountKeyPair.address);

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

    // check recent transactions
    var recentTransactions =
        await account.loadRecentTransactions(accountKeyPair.address, limit: 2);
    assert(recentTransactions.length == 2);
    assert(recentTransactions.first.successful);
    assert(recentTransactions.first.operationCount == 1);
    assert(recentTransactions.last.successful);
    assert(recentTransactions.last.operationCount == 1);
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
    assert(newAccount.sequenceNumber > BigInt.zero);
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
    await stellar.fundTestNetAccount(sponsorKeyPair.address);

    var sponsoredKeyPair = account.createKeyPair();
    await stellar.fundTestNetAccount(sponsoredKeyPair.address);

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
    await stellar.fundTestNetAccount(sponsorKeyPair.address);

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
    await stellar.fundTestNetAccount(sponsorKeyPair.address);

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
    await stellar.fundTestNetAccount(sponsorKeyPair.address);

    var sponsoredKeyPair = account.createKeyPair();
    await stellar.fundTestNetAccount(sponsoredKeyPair.address);

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
    assert(newAccount.sequenceNumber > BigInt.zero);
    var balances = newAccount.balances;
    assert(balances.length == 1);
    assert(balances[0].assetType == 'native');
    assert(double.parse(balances[0].balance) == 0.0);
  });

  test('submit transaction with fee increase', () async {
    var account1KeyPair = account.createKeyPair();
    await stellar.fundTestNetAccount(account1KeyPair.address);
    var account2KeyPair = account.createKeyPair();
    await stellar.fundTestNetAccount(account2KeyPair.address);

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
    assert(newAccount.sequenceNumber > BigInt.zero);
    var balances = newAccount.balances;
    assert(balances.length == 1);
    assert(balances[0].assetType == 'native');
    assert(double.parse(balances[0].balance) == 10010.0);

    var server = stellar.server;
    var transactions =
        await server.transactions.forAccount(newAccount.accountId).execute();

    assert(transactions.records.length == 2);
    /*for (var tx in transactions.records!) {
      print(tx.hash);
    }*/
  });

  test('test path payments', () async {
    final keyPairA = account.createKeyPair();
    await stellar.fundTestNetAccount(keyPairA.address);
    final accountAId = keyPairA.address;

    final keyPairB = account.createKeyPair();
    final accountBId = keyPairB.address;

    final keyPairC = account.createKeyPair();
    final accountCId = keyPairC.address;

    final keyPairD = account.createKeyPair();
    final accountDId = keyPairD.address;

    final keyPairE = account.createKeyPair();
    final accountEId = keyPairE.address;

    // fund the other accounts.

    var txBuilder = await stellar.transaction(keyPairA);
    var createAccountsTransaction = txBuilder
        .createAccount(keyPairB, startingBalance: "10")
        .createAccount(keyPairC, startingBalance: "10")
        .createAccount(keyPairD, startingBalance: "10")
        .createAccount(keyPairE, startingBalance: "10")
        .build();
    stellar.sign(createAccountsTransaction, keyPairA);

    // submit transaction to the network
    var success = await stellar.submitTransaction(createAccountsTransaction);
    assert(success);

    // create assets for testing
    final iomAsset = IssuedAssetId(code: 'IOM', issuer: accountAId);
    final ecoAsset = IssuedAssetId(code: 'ECO', issuer: accountAId);
    final moonAsset = IssuedAssetId(code: 'MOON', issuer: accountAId);

    // let c trust iom
    txBuilder = await stellar.transaction(keyPairC);
    var trustTransaction =
        txBuilder.addAssetSupport(iomAsset, limit: "200999").build();
    stellar.sign(trustTransaction, keyPairC);

    success = await stellar.submitTransaction(trustTransaction);
    assert(success);

    // let b trust iom and eco
    txBuilder = await stellar.transaction(keyPairB);
    trustTransaction = txBuilder
        .addAssetSupport(iomAsset, limit: "200999")
        .addAssetSupport(ecoAsset, limit: "200999")
        .build();
    stellar.sign(trustTransaction, keyPairB);

    success = await stellar.submitTransaction(trustTransaction);
    assert(success);

    // let d trust eco and moon
    txBuilder = await stellar.transaction(keyPairD);
    trustTransaction = txBuilder
        .addAssetSupport(ecoAsset, limit: "200999")
        .addAssetSupport(moonAsset, limit: "200999")
        .build();
    stellar.sign(trustTransaction, keyPairD);

    success = await stellar.submitTransaction(trustTransaction);
    assert(success);

    // let e trust moon
    txBuilder = await stellar.transaction(keyPairE);
    trustTransaction =
        txBuilder.addAssetSupport(moonAsset, limit: "200999").build();
    stellar.sign(trustTransaction, keyPairE);

    success = await stellar.submitTransaction(trustTransaction);
    assert(success);

    // fund accounts with issued assets
    txBuilder = await stellar.transaction(keyPairA);
    var fundTransaction = txBuilder
        .transfer(accountCId, iomAsset, "100")
        .transfer(accountBId, iomAsset, "100")
        .transfer(accountBId, ecoAsset, "100")
        .transfer(accountDId, moonAsset, "100")
        .build();
    stellar.sign(fundTransaction, keyPairA);
    success = await stellar.submitTransaction(fundTransaction);
    assert(success);

    // B makes offer: sell 100 ECO - buy IOM, price 0.5
    var sellOfferOpB = flutter_sdk.ManageSellOfferOperationBuilder(
      ecoAsset.toAsset(),
      iomAsset.toAsset(),
      "100",
      "0.5",
    ).build();

    // D makes offer: sell 100 MOON - buy ECO, price 0.5
    var sellOfferOpD = flutter_sdk.ManageSellOfferOperationBuilder(
      moonAsset.toAsset(),
      ecoAsset.toAsset(),
      "100",
      "0.5",
    ).setSourceAccount(accountDId).build();

    txBuilder = await stellar.transaction(keyPairB);
    var sellOfferTransaction =
        txBuilder.addOperation(sellOfferOpB).addOperation(sellOfferOpD).build();
    stellar.sign(sellOfferTransaction, keyPairB);
    stellar.sign(sellOfferTransaction, keyPairD);

    success = await stellar.submitTransaction(sellOfferTransaction);
    assert(success);

    // wait a bit for the ledger to close
    await Future.delayed(const Duration(seconds: 3), () {});

    // check if we can find the path to send 10 IOM to E, since E does not trust IOM
    // expected IOM->ECO->MOON
    var paymentPaths = await stellar.findStrictSendPathForDestinationAddress(
        iomAsset, "10", accountEId);
    assert(paymentPaths.length == 1);
    var paymentPath = paymentPaths.first;

    assert(paymentPath.destinationAsset == moonAsset);
    assert(paymentPath.sourceAsset == iomAsset);

    assert(double.parse(paymentPath.sourceAmount) == 10);
    assert(double.parse(paymentPath.destinationAmount) == 40);

    var assetsPath = paymentPath.path;
    assert(assetsPath.length == 1);
    assert(assetsPath.first == ecoAsset);

    paymentPaths = await stellar
        .findStrictSendPathForDestinationAssets(iomAsset, "10", [moonAsset]);
    assert(paymentPaths.length == 1);
    paymentPath = paymentPaths.first;

    assert(paymentPath.destinationAsset == moonAsset);
    assert(paymentPath.sourceAsset == iomAsset);

    assert(double.parse(paymentPath.sourceAmount) == 10);
    assert(double.parse(paymentPath.destinationAmount) == 40);

    assetsPath = paymentPath.path;
    assert(assetsPath.length == 1);
    assert(assetsPath.first == ecoAsset);

    // C sends IOM to E (she receives MOON)
    txBuilder = await stellar.transaction(keyPairC);
    var strictSendTransaction = txBuilder
        .strictSend(
            sendAssetId: iomAsset,
            sendAmount: "5",
            destinationAddress: accountEId,
            destinationAssetId: moonAsset,
            destinationMinAmount: "19",
            path: assetsPath)
        .build();
    stellar.sign(strictSendTransaction, keyPairC);

    success = await stellar.submitTransaction(strictSendTransaction);
    assert(success);

    // test also "pathPay"
    txBuilder = await stellar.transaction(keyPairC);
    var pathPayTransaction = txBuilder
        .pathPay(
            destinationAddress: accountEId,
            sendAsset: iomAsset,
            destinationAsset: moonAsset,
            sendAmount: "5",
            destMin: "19",
            path: assetsPath)
        .build();
    stellar.sign(pathPayTransaction, keyPairC);
    try {
      success = await stellar.submitTransaction(pathPayTransaction);
      assert(success);
    } on TransactionSubmitFailedException catch (e) {
      fail('could not send path payment : ${e.response.resultXdr}');
    }

    // check if E received MOON
    var info = await stellar.account().getInfo(accountEId);
    var balances = info.balances.where(
        (balance) => StellarAssetId.fromAsset(balance.asset) == moonAsset);
    assert(balances.isNotEmpty);
    var moonBalanceOfE = double.parse(balances.first.balance);
    assert(moonBalanceOfE == 40.0);

    // next lets check strict receive

    // for source account
    paymentPaths = await stellar.findStrictReceivePathForSourceAddress(
        moonAsset, "8", accountCId);
    assert(paymentPaths.length == 1);
    paymentPath = paymentPaths.first;

    assert(paymentPath.destinationAsset == moonAsset);
    assert(paymentPath.sourceAsset == iomAsset);

    assert(double.parse(paymentPath.sourceAmount) == 2);
    assert(double.parse(paymentPath.destinationAmount) == 8);

    assetsPath = paymentPath.path;
    assert(assetsPath.length == 1);
    assert(assetsPath.first == ecoAsset);

    // for source assets
    paymentPaths = await stellar
        .findStrictReceivePathForSourceAssets(moonAsset, "8", [iomAsset]);
    assert(paymentPaths.length == 1);
    paymentPath = paymentPaths.first;

    assert(paymentPath.destinationAsset == moonAsset);
    assert(paymentPath.sourceAsset == iomAsset);

    assert(double.parse(paymentPath.sourceAmount) == 2);
    assert(double.parse(paymentPath.destinationAmount) == 8);

    assetsPath = paymentPath.path;
    assert(assetsPath.length == 1);
    assert(assetsPath.first == ecoAsset);

    // send to E
    txBuilder = await stellar.transaction(keyPairC);
    var strictReceiveTransaction = txBuilder
        .strictReceive(
            sendAssetId: iomAsset,
            sendMaxAmount: "2",
            destinationAddress: accountEId,
            destinationAssetId: moonAsset,
            destinationAmount: "8",
            path: assetsPath)
        .build();
    stellar.sign(strictReceiveTransaction, keyPairC);

    success = await stellar.submitTransaction(strictReceiveTransaction);
    assert(success);

    // check if E received MOON
    info = await stellar.account().getInfo(accountEId);
    balances = info.balances.where(
        (balance) => StellarAssetId.fromAsset(balance.asset) == moonAsset);
    assert(balances.isNotEmpty);
    moonBalanceOfE = double.parse(balances.first.balance);
    assert(moonBalanceOfE == 48.0);

    // check recent payments
    var recentPayments =
        await account.loadRecentPayments(keyPairC.address, limit: 2);
    assert(recentPayments.length == 2);
    assert(recentPayments.first
        is flutter_sdk.PathPaymentStrictReceiveOperationResponse);
    assert(recentPayments.last
        is flutter_sdk.PathPaymentStrictSendOperationResponse);
  });

  test('account merge', () async {
    var accountKp = account.createKeyPair();
    var sourceKp = account.createKeyPair();
    await stellar.fundTestNetAccount(accountKp.address);
    await stellar.fundTestNetAccount(sourceKp.address);

    var txBuilder = await stellar.transaction(accountKp, baseFee: 1000);
    var mergeTxn = txBuilder
        .accountMerge(
          destinationAddress: accountKp.address,
          sourceAddress: sourceKp.address,
        )
        .build();

    stellar.sign(mergeTxn, accountKp);
    stellar.sign(mergeTxn, sourceKp);
    bool success = await stellar.submitTransaction(mergeTxn);
    assert(success);

    // validate
    var exists = await account.accountExists(sourceKp.address);
    assert(!exists);
  });

  test('set memo', () async {
    var accountKeyPair = account.createKeyPair();
    await stellar.fundTestNetAccount(accountKeyPair.address);

    var newAccountKeyPair = account.createKeyPair();

    var txBuilder = await stellar.transaction(accountKeyPair);

    txBuilder.createAccount(newAccountKeyPair, startingBalance: "100.1");
    var memo = flutter_sdk.MemoText("Memo string");
    var tx = txBuilder.setMemo(memo).build();

    stellar.sign(tx, accountKeyPair);
    bool success = await stellar.submitTransaction(tx);
    assert(success);
  });

  test('fund testnet account', () async {
    var accountKp = account.createKeyPair();
    await wallet.stellar().fundTestNetAccount(accountKp.address);

    // validate
    var exists = await account.accountExists(accountKp.address);
    assert(exists);
  });

  test('add operation', () async {
    var sourceAccountKeyPair = account.createKeyPair();
    await stellar.fundTestNetAccount(sourceAccountKeyPair.address);

    var txBuilder = await stellar.transaction(sourceAccountKeyPair);

    var key = "web_auth_domain";
    var value = "https://testanchor.stellar.org";
    var valueBytes = Uint8List.fromList(value.codeUnits);

    var manageDataOperation = flutter_sdk.ManageDataOperationBuilder(
      key,
      valueBytes,
    ).build();

    var tx = txBuilder.addOperation(
      manageDataOperation,
    ).build();
    stellar.sign(tx, sourceAccountKeyPair);
    bool success = await stellar.submitTransaction(tx);
    assert(success);
  });
}
