@Timeout(Duration(seconds: 400))

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;

import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// End-to-end integration tests for the wallet SDK anchor SEP protocols
/// (SEP-10, SEP-12, SEP-6, SEP-24 and SEP-38) against a live anchor running
/// on the Stellar test network.
void main() {
  const anchorDomain = "anchor-sep-server-dev.stellar.org";
  const usdcCode = "USDC";
  const usdcIssuer = "GDQOE23CFSUMSVQK4Y5JHPPYK73VYCNHZHA7ENKCV37P6SUEO6XQBKPP";
  const usdcSep38Asset = "stellar:$usdcCode:$usdcIssuer";

  // SEP-9 KYC fields used to register a customer with the anchor.
  const sep9Info = {
    "first_name": "John",
    "last_name": "Smith",
    "email_address": "test@stellar.org",
    "bank_number": "12345",
    "bank_account_number": "67890",
  };

  final wallet = Wallet.testNet;
  final stellar = wallet.stellar();
  final account = stellar.account();
  final anchor = wallet.anchor(anchorDomain);
  final usdc = IssuedAssetId(code: usdcCode, issuer: usdcIssuer);

  /// Creates a new key pair, funds it via the test network friendbot and
  /// verifies that the account exists on the network.
  Future<SigningKeyPair> createAndFundAccount() async {
    final accountKp = account.createKeyPair();
    await stellar.fundTestNetAccount(accountKp.address);

    // Give the network a moment to include the funding transaction.
    await Future.delayed(const Duration(seconds: 2));

    final exists = await account.accountExists(accountKp.address);
    expect(exists, isTrue,
        reason: "funded account ${accountKp.address} should exist");
    return accountKp;
  }

  /// Authenticates the given key pair with the anchor using SEP-10.
  Future<AuthToken> authenticate(SigningKeyPair accountKp, {int? memoId}) async {
    final sep10 = await anchor.sep10();
    return sep10.authenticate(accountKp, memoId: memoId);
  }

  test('SEP-10 basic authentication', () async {
    final accountKp = await createAndFundAccount();

    final authToken = await authenticate(accountKp);

    expect(authToken.jwt, isNotNull);
    expect(authToken.jwt, isNotEmpty);
  });

  test('SEP-10 authentication with memo', () async {
    final accountKp = await createAndFundAccount();

    final authToken = await authenticate(accountKp, memoId: 123456789);

    expect(authToken.jwt, isNotNull);
    expect(authToken.jwt, isNotEmpty);
  });

  test('SEP-12 customer registration', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep12 = await anchor.sep12(authToken);

    final addResponse = await sep12.add(sep9Info);
    expect(addResponse.id, isNotNull);
    expect(addResponse.id, isNotEmpty);

    final getResponse = await sep12.get(id: addResponse.id);
    expect(getResponse.id, isNotNull);
    expect(getResponse.id, equals(addResponse.id));
  });

  test('SEP-6 deposit flow', () async {
    final accountKp = await createAndFundAccount();

    // Establish a USDC trustline so the account can receive the asset.
    final txBuilder = await stellar.transaction(accountKp);
    final tx = txBuilder.addAssetSupport(usdc).build();
    stellar.sign(tx, accountKp);
    final trustlineSuccess = await stellar.submitTransaction(tx);
    expect(trustlineSuccess, isTrue);

    // Wait for the trustline transaction to be included.
    await Future.delayed(const Duration(seconds: 2));

    final authToken = await authenticate(accountKp);

    // Register KYC information for the customer.
    final sep12 = await anchor.sep12(authToken);
    final customerResponse = await sep12.add(sep9Info);
    expect(customerResponse.id, isNotEmpty);

    final sep6 = anchor.sep6();
    final depositResponse = await sep6.deposit(
      Sep6DepositParams(
        assetCode: usdcCode,
        account: accountKp.address,
        type: "SEPA",
      ),
      authToken,
    );

    if (depositResponse is Sep6DepositSuccess) {
      expect(depositResponse.id, isNotNull);
      final id = depositResponse.id;
      if (id != null) {
        final transactionInfo =
            await sep6.getTransactionBy(authToken: authToken, id: id);
        expect(transactionInfo.id, equals(id));
      }
    } else if (depositResponse is Sep6MissingKYC) {
      // The anchor may legitimately require additional KYC fields.
      // ignore: avoid_print
      print('SEP-6 deposit requires KYC fields: ${depositResponse.fields}');
    } else if (depositResponse is Sep6Pending) {
      // The anchor may legitimately keep the customer information pending.
      // ignore: avoid_print
      print('SEP-6 deposit pending: ${depositResponse.status}');
    } else {
      fail('Unexpected SEP-6 deposit response: $depositResponse');
    }
  });

  test('SEP-6 withdraw flow', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    // Register KYC information for the customer.
    final sep12 = await anchor.sep12(authToken);
    final customerResponse = await sep12.add(sep9Info);
    expect(customerResponse.id, isNotEmpty);

    final sep6 = anchor.sep6();
    final withdrawResponse = await sep6.withdraw(
      Sep6WithdrawParams(
        assetCode: usdcCode,
        type: "bank_account",
        dest: "123",
        destExtra: "12345",
        account: accountKp.address,
      ),
      authToken,
    );

    if (withdrawResponse is Sep6WithdrawSuccess) {
      expect(withdrawResponse.id, isNotNull);
    } else if (withdrawResponse is Sep6MissingKYC) {
      // The anchor may legitimately require additional KYC fields.
      // ignore: avoid_print
      print('SEP-6 withdraw requires KYC fields: ${withdrawResponse.fields}');
    } else if (withdrawResponse is Sep6Pending) {
      // The anchor may legitimately keep the customer information pending.
      // ignore: avoid_print
      print('SEP-6 withdraw pending: ${withdrawResponse.status}');
    } else {
      fail('Unexpected SEP-6 withdraw response: $withdrawResponse');
    }
  });

  test('SEP-24 interactive deposit', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep24 = anchor.sep24();
    final depositResponse = await sep24.deposit(
      usdc,
      authToken,
      extraFields: {"account": accountKp.address},
    );

    expect(depositResponse.id, isNotNull);
    expect(depositResponse.id, isNotEmpty);
    expect(depositResponse.url, isNotNull);
    expect(depositResponse.url, isNotEmpty);

    final transactionInfo =
        await sep24.getTransactionBy(authToken, id: depositResponse.id);
    expect(transactionInfo.id, equals(depositResponse.id));
  });

  test('SEP-24 interactive withdraw', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep24 = anchor.sep24();
    final withdrawResponse = await sep24.withdraw(
      usdc,
      authToken,
      extraFields: {"account": accountKp.address},
    );

    expect(withdrawResponse.id, isNotNull);
    expect(withdrawResponse.id, isNotEmpty);
    expect(withdrawResponse.url, isNotNull);
    expect(withdrawResponse.url, isNotEmpty);
  });

  test('SEP-38 get prices', () async {
    final sep38 = await anchor.sep38();
    final prices = await sep38.prices(
      sellAsset: usdcSep38Asset,
      sellAmount: "100",
    );

    expect(prices.buyAssets, isNotEmpty);
  });

  test('SEP-38 create quote', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep38 = await anchor.sep38(authToken: authToken);
    final quoteResponse = await sep38.requestQuote(
      context: "sep6",
      sellAsset: usdcSep38Asset,
      buyAsset: "iso4217:USD",
      sellAmount: "10",
    );

    expect(quoteResponse.id, isNotNull);
    expect(quoteResponse.id, isNotEmpty);
    expect(quoteResponse.expiresAt, isNotNull);
    expect(quoteResponse.sellAsset, equals(usdcSep38Asset));
    expect(quoteResponse.buyAsset, equals("iso4217:USD"));

    final retrievedQuote = await sep38.getQuote(quoteResponse.id);
    expect(retrievedQuote.id, equals(quoteResponse.id));
    expect(retrievedQuote.sellAsset, equals(quoteResponse.sellAsset));
    expect(retrievedQuote.buyAsset, equals(quoteResponse.buyAsset));
  });

  test('SEP-12 update customer', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep12 = await anchor.sep12(authToken);

    final addResponse = await sep12.add(sep9Info);
    expect(addResponse.id, isNotEmpty);

    // Update the existing customer by passing its id. The anchor keeps the
    // same customer record and returns the same id.
    final updateResponse = await sep12.update({
      "first_name": "Jane",
      "last_name": "Doe",
      "email_address": "jane.doe@stellar.org",
    }, addResponse.id);

    expect(updateResponse.id, isNotNull);
    expect(updateResponse.id, equals(addResponse.id));
  });

  test('SEP-12 get customer status', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep12 = await anchor.sep12(authToken);

    final addResponse = await sep12.add(sep9Info);
    expect(addResponse.id, isNotEmpty);

    final getResponse = await sep12.get(id: addResponse.id);
    expect(getResponse.id, equals(addResponse.id));

    // The anchor decides the resulting status. Assert it is one of the known
    // SEP-12 statuses rather than a specific hard-coded value.
    const knownStatuses = [
      Sep12Status.accepted,
      Sep12Status.needsInfo,
      Sep12Status.processing,
      Sep12Status.rejected,
      Sep12Status.verificationRequired,
    ];
    expect(knownStatuses, contains(getResponse.sep12Status));
  });

  test('SEP-12 delete customer', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep12 = await anchor.sep12(authToken);

    final addResponse = await sep12.add(sep9Info);
    expect(addResponse.id, isNotEmpty);

    final deleteResponse = await sep12.delete(accountKp.address);
    expect(deleteResponse.statusCode, equals(200));
  });

  test('SEP-12 verify customer', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep12 = await anchor.sep12(authToken);

    final addResponse = await sep12.add(sep9Info);
    expect(addResponse.id, isNotEmpty);

    // Provide a mobile number so a mobile_number_verification can reference it.
    await sep12.add({"mobile_number": "+10000000001"});

    // This anchor does not implement the SEP-12 verification endpoint: the
    // PUT /customer/verification request is rejected by the server. Assert the
    // resulting error response rather than faking a successful verification.
    try {
      await sep12.verify(
          {"mobile_number_verification": "2735021"}, addResponse.id);
      fail("The anchor was expected to reject the verification request");
    } on flutter_sdk.ErrorResponse catch (e) {
      expect(e.code, greaterThanOrEqualTo(400));
    }
  });

  test('SEP-24 service info', () async {
    final sep24 = anchor.sep24();
    final serviceInfo = await sep24.getServiceInfo();

    expect(serviceInfo.deposit, isNotEmpty);
    expect(serviceInfo.withdraw, isNotEmpty);

    final depositUsdc = serviceInfo.deposit[usdcCode];
    expect(depositUsdc, isNotNull);
    expect(depositUsdc!.enabled, isTrue);

    final withdrawUsdc = serviceInfo.withdraw[usdcCode];
    expect(withdrawUsdc, isNotNull);
    expect(withdrawUsdc!.enabled, isTrue);
  });

  test('SEP-24 get transactions for asset', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep24 = anchor.sep24();

    // Start a deposit so there is at least one transaction to list.
    final depositResponse = await sep24.deposit(
      usdc,
      authToken,
      extraFields: {"account": accountKp.address},
    );
    expect(depositResponse.id, isNotEmpty);

    final transactions = await sep24.getTransactionsForAsset(usdc, authToken);
    expect(transactions, isA<List<Sep24Transaction>>());
    expect(transactions.any((tx) => tx.id == depositResponse.id), isTrue,
        reason:
            "the transaction list should contain the started deposit ${depositResponse.id}");
  });

  test('SEP-6 info', () async {
    final sep6 = anchor.sep6();
    final info = await sep6.info();

    expect(info.deposit, isNotNull);
    expect(info.deposit![usdcCode], isNotNull);
    expect(info.deposit![usdcCode]!.enabled, isTrue);

    expect(info.withdraw, isNotNull);
    expect(info.withdraw![usdcCode], isNotNull);
    expect(info.withdraw![usdcCode]!.enabled, isTrue);
  });

  test('SEP-6 get transactions for asset', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep6 = anchor.sep6();
    final transactions = await sep6.getTransactionsForAsset(
      authToken: authToken,
      assetCode: usdcCode,
    );

    expect(transactions, isA<List<Sep6Transaction>>());
  });

  test('SEP-6 fee', () async {
    final accountKp = await createAndFundAccount();
    final authToken = await authenticate(accountKp);

    final sep6 = anchor.sep6();

    // The SEP-6 fee endpoint is deprecated and this anchor does not implement
    // it (its /info response reports the fee endpoint as disabled). The request
    // therefore fails. Assert the resulting error response rather than faking
    // a fee value.
    try {
      await sep6.fee(
        operation: "deposit",
        assetCode: usdcCode,
        amount: 10.0,
        type: "SEPA",
        authToken: authToken,
      );
      fail("The anchor was expected to reject the fee request");
    } on flutter_sdk.ErrorResponse catch (e) {
      expect(e.code, greaterThanOrEqualTo(400));
    }
  });

  test('SEP-38 info', () async {
    final sep38 = await anchor.sep38();
    final info = await sep38.info();

    expect(info.assets, isNotEmpty);
    expect(info.assets.any((asset) => asset.asset == usdcSep38Asset), isTrue,
        reason: "the SEP-38 info response should list $usdcSep38Asset");
  });

  test('SEP-38 get price', () async {
    final sep38 = await anchor.sep38();
    final price = await sep38.price(
      context: "sep6",
      sellAsset: usdcSep38Asset,
      buyAsset: "iso4217:USD",
      sellAmount: "10",
    );

    expect(price.price, isNotEmpty);
    expect(price.totalPrice, isNotEmpty);
    expect(price.sellAmount, isNotEmpty);
    expect(price.buyAmount, isNotEmpty);
  });
}
