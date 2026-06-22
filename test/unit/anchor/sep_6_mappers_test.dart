// Copyright 2024 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// Builds an unsigned JWT carrying the given [payload] claims, sufficient for
/// AuthToken construction in tests (the signature is not verified).
String _testJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${seg({'alg': 'none', 'typ': 'JWT'})}.${seg(payload)}.sig';
}

void main() {
  group('Sep6DepositParams toDepositRequest Tests', () {
    late Sep6DepositParams params;

    setUp(() {
      params = Sep6DepositParams(
        assetCode: 'USDC',
        account: 'GACCOUNTDEPOSITXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        memoType: MemoType.id,
        memo: '123456',
        emailAddress: 'depositor@example.com',
        type: 'SEPA',
        walletName: 'Demo Wallet',
        walletUrl: 'https://wallet.example.com',
        lang: 'en',
        onChangeCallback: 'https://wallet.example.com/callback',
        amount: '120.50',
        countryCode: 'USA',
        claimableBalanceSupported: 'true',
        customerId: 'cust-1',
        locationId: 'loc-1',
        extraFields: {'bank_branch': 'central'},
      );
    });

    test('maps every field including memoType.value', () {
      final request = params.toDepositRequest();

      expect(request.assetCode, 'USDC');
      expect(request.account,
          'GACCOUNTDEPOSITXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
      // memoType must be mapped from the enum value, not its toString().
      expect(request.memoType, 'id');
      expect(request.memo, '123456');
      expect(request.emailAddress, 'depositor@example.com');
      expect(request.type, 'SEPA');
      expect(request.walletName, 'Demo Wallet');
      expect(request.walletUrl, 'https://wallet.example.com');
      expect(request.lang, 'en');
      expect(request.onChangeCallback, 'https://wallet.example.com/callback');
      expect(request.amount, '120.50');
      expect(request.countryCode, 'USA');
      expect(request.claimableBalanceSupported, 'true');
      expect(request.customerId, 'cust-1');
      expect(request.locationId, 'loc-1');
      expect(request.extraFields, {'bank_branch': 'central'});
    });

    test('maps text memoType value', () {
      final request = Sep6DepositParams(
        assetCode: 'USDC',
        account: 'GACCOUNT',
        memoType: MemoType.text,
      ).toDepositRequest();

      expect(request.memoType, 'text');
    });

    test('maps hash memoType value', () {
      final request = Sep6DepositParams(
        assetCode: 'USDC',
        account: 'GACCOUNT',
        memoType: MemoType.hash,
      ).toDepositRequest();

      expect(request.memoType, 'hash');
    });

    test('leaves memoType null when not provided', () {
      final request = Sep6DepositParams(
        assetCode: 'USDC',
        account: 'GACCOUNT',
      ).toDepositRequest();

      expect(request.memoType, isNull);
      expect(request.memo, isNull);
      expect(request.extraFields, isNull);
    });
  });

  group('Sep6DepositExchangeParams toDepositExchangeRequest Tests', () {
    late Sep6DepositExchangeParams params;

    setUp(() {
      params = Sep6DepositExchangeParams(
        destinationAssetCode: 'USDC',
        sourceAssetId: FiatAssetId('BRL'),
        amount: '500',
        account: 'GEXCHANGEDEPOSITXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        quoteId: 'quote-123',
        memoType: MemoType.text,
        memo: 'ref-99',
        emailAddress: 'exchange@example.com',
        type: 'bank_account',
        walletName: 'Demo Wallet',
        walletUrl: 'https://wallet.example.com',
        lang: 'pt',
        onChangeCallback: 'https://wallet.example.com/cb',
        countryCode: 'BRA',
        claimableBalanceSupported: 'false',
        customerId: 'cust-2',
        locationId: 'loc-2',
        extraFields: {'pix_key': 'abc'},
      );
    });

    test('maps every field including sourceAssetId.sep38 and memoType.value',
        () {
      final request = params.toDepositExchangeRequest();

      expect(request.destinationAsset, 'USDC');
      // The source asset must be serialized using the SEP-38 identifier.
      expect(request.sourceAsset, 'iso4217:BRL');
      expect(request.amount, '500');
      expect(request.account,
          'GEXCHANGEDEPOSITXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
      expect(request.quoteId, 'quote-123');
      expect(request.memoType, 'text');
      expect(request.memo, 'ref-99');
      expect(request.emailAddress, 'exchange@example.com');
      expect(request.type, 'bank_account');
      expect(request.walletName, 'Demo Wallet');
      expect(request.walletUrl, 'https://wallet.example.com');
      expect(request.lang, 'pt');
      expect(request.onChangeCallback, 'https://wallet.example.com/cb');
      expect(request.countryCode, 'BRA');
      expect(request.claimableBalanceSupported, 'false');
      expect(request.customerId, 'cust-2');
      expect(request.locationId, 'loc-2');
      expect(request.extraFields, {'pix_key': 'abc'});
    });

    test('serializes an issued stellar asset as source via sep38', () {
      final request = Sep6DepositExchangeParams(
        destinationAssetCode: 'USDC',
        sourceAssetId: FiatAssetId('NGN'),
        amount: '10',
        account: 'GACCOUNT',
      ).toDepositExchangeRequest();

      expect(request.sourceAsset, 'iso4217:NGN');
      expect(request.memoType, isNull);
    });
  });

  group('Sep6WithdrawParams toWithdrawRequest Tests', () {
    late Sep6WithdrawParams params;

    setUp(() {
      params = Sep6WithdrawParams(
        assetCode: 'USDC',
        type: 'bank_account',
        dest: 'DE89370400440532013000',
        destExtra: 'COBADEFFXXX',
        account: 'GWITHDRAWACCOUNTXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        memo: 'wmemo',
        memoType: MemoType.id,
        walletName: 'Demo Wallet',
        walletUrl: 'https://wallet.example.com',
        lang: 'en',
        onChangeCallback: 'https://wallet.example.com/cb',
        amount: '75',
        countryCode: 'DEU',
        refundMemo: 'refund-1',
        refundMemoType: MemoType.text,
        customerId: 'cust-3',
        locationId: 'loc-3',
        extraFields: {'account_holder': 'Jane'},
      );
    });

    test('maps every field including memoType.value and refundMemoType.value',
        () {
      final request = params.toWithdrawRequest();

      expect(request.assetCode, 'USDC');
      expect(request.type, 'bank_account');
      expect(request.dest, 'DE89370400440532013000');
      expect(request.destExtra, 'COBADEFFXXX');
      expect(request.account,
          'GWITHDRAWACCOUNTXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
      expect(request.memo, 'wmemo');
      expect(request.memoType, 'id');
      expect(request.walletName, 'Demo Wallet');
      expect(request.walletUrl, 'https://wallet.example.com');
      expect(request.lang, 'en');
      expect(request.onChangeCallback, 'https://wallet.example.com/cb');
      expect(request.amount, '75');
      expect(request.countryCode, 'DEU');
      expect(request.refundMemo, 'refund-1');
      expect(request.refundMemoType, 'text');
      expect(request.customerId, 'cust-3');
      expect(request.locationId, 'loc-3');
      expect(request.extraFields, {'account_holder': 'Jane'});
    });

    test('leaves memoType and refundMemoType null when not provided', () {
      final request = Sep6WithdrawParams(
        assetCode: 'USDC',
        type: 'cash',
      ).toWithdrawRequest();

      expect(request.memoType, isNull);
      expect(request.refundMemoType, isNull);
      expect(request.dest, isNull);
    });
  });

  group('Sep6WithdrawExchangeParams toWithdrawExchangeRequest Tests', () {
    late Sep6WithdrawExchangeParams params;

    setUp(() {
      params = Sep6WithdrawExchangeParams(
        sourceAssetCode: 'USDC',
        destinationAssetId: FiatAssetId('NGN'),
        amount: '200',
        type: 'bank_account',
        dest: '0123456789',
        destExtra: 'GTBINGLA',
        quoteId: 'quote-456',
        account: 'GWEXCHANGEXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        memo: 'wxmemo',
        memoType: MemoType.hash,
        walletName: 'Demo Wallet',
        walletUrl: 'https://wallet.example.com',
        lang: 'en',
        onChangeCallback: 'https://wallet.example.com/cb',
        countryCode: 'NGA',
        claimableBalanceSupported: 'true',
        refundMemo: 'refund-x',
        refundMemoType: MemoType.id,
        customerId: 'cust-4',
        locationId: 'loc-4',
        extraFields: {'note': 'urgent'},
      );
    });

    test(
        'maps every field including destinationAssetId.sep38, memoType.value, '
        'refundMemoType.value', () {
      final request = params.toWithdrawExchangeRequest();

      expect(request.sourceAsset, 'USDC');
      // The destination asset must be serialized using the SEP-38 identifier.
      expect(request.destinationAsset, 'iso4217:NGN');
      expect(request.amount, '200');
      expect(request.type, 'bank_account');
      expect(request.dest, '0123456789');
      expect(request.destExtra, 'GTBINGLA');
      expect(request.quoteId, 'quote-456');
      expect(request.account,
          'GWEXCHANGEXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
      expect(request.memo, 'wxmemo');
      expect(request.memoType, 'hash');
      expect(request.walletName, 'Demo Wallet');
      expect(request.walletUrl, 'https://wallet.example.com');
      expect(request.lang, 'en');
      expect(request.onChangeCallback, 'https://wallet.example.com/cb');
      expect(request.countryCode, 'NGA');
      expect(request.claimableBalanceSupported, 'true');
      expect(request.refundMemo, 'refund-x');
      expect(request.refundMemoType, 'id');
      expect(request.customerId, 'cust-4');
      expect(request.locationId, 'loc-4');
      expect(request.extraFields, {'note': 'urgent'});
    });
  });

  group('Sep6Transaction fromAnchorTransaction Tests', () {
    test('maps scalar fields and parses provided dates', () {
      final anchorTx = flutter_sdk.AnchorTransaction(
        id: 'tx-1',
        kind: 'deposit',
        status: 'completed',
        statusEta: 600,
        moreInfoUrl: 'https://anchor.example.com/tx/tx-1',
        amountIn: '100.0000000',
        amountInAsset: 'iso4217:USD',
        amountOut: '98.0000000',
        amountOutAsset:
            'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
        amountFee: '2.0000000',
        amountFeeAsset: 'iso4217:USD',
        quoteId: 'quote-1',
        from: 'sender-account',
        to: 'GDESTINATION',
        externalExtra: '021000021',
        externalExtraText: 'Example Bank',
        depositMemo: 'dmemo',
        depositMemoType: 'text',
        withdrawAnchorAccount: 'GANCHOR',
        withdrawMemo: 'wmemo',
        withdrawMemoType: 'id',
        startedAt: '2024-01-02T03:04:05Z',
        updatedAt: '2024-01-03T06:07:08Z',
        completedAt: '2024-01-04T09:10:11Z',
        userActionRequiredBy: '2024-01-05T12:13:14Z',
        stellarTransactionId: 'stellar-tx-1',
        externalTransactionId: 'ext-tx-1',
        message: 'all good',
        refunded: false,
        requiredInfoMessage: null,
        claimableBalanceId: 'cb-1',
      );

      final tx = Sep6Transaction.fromAnchorTransaction(anchorTx);

      expect(tx.id, 'tx-1');
      expect(tx.status.value, 'completed');
      expect(tx.kind, 'deposit');
      expect(tx.statusEta, 600);
      expect(tx.moreInfoUrl, 'https://anchor.example.com/tx/tx-1');
      expect(tx.amountIn, '100.0000000');
      expect(tx.amountInAsset, 'iso4217:USD');
      expect(tx.amountOut, '98.0000000');
      expect(tx.amountOutAsset,
          'stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN');
      expect(tx.amountFee, '2.0000000');
      expect(tx.amountFeeAsset, 'iso4217:USD');
      expect(tx.quoteId, 'quote-1');
      expect(tx.from, 'sender-account');
      expect(tx.to, 'GDESTINATION');
      expect(tx.externalExtra, '021000021');
      expect(tx.externalExtraText, 'Example Bank');
      expect(tx.depositMemo, 'dmemo');
      expect(tx.depositMemoType, 'text');
      expect(tx.withdrawAnchorAccount, 'GANCHOR');
      expect(tx.withdrawMemo, 'wmemo');
      expect(tx.withdrawMemoType, 'id');
      expect(tx.startedAt, DateTime.parse('2024-01-02T03:04:05Z'));
      expect(tx.updatedAt, DateTime.parse('2024-01-03T06:07:08Z'));
      expect(tx.completedAt, DateTime.parse('2024-01-04T09:10:11Z'));
      expect(tx.userActionRequiredBy, DateTime.parse('2024-01-05T12:13:14Z'));
      expect(tx.stellarTransactionId, 'stellar-tx-1');
      expect(tx.externalTransactionId, 'ext-tx-1');
      expect(tx.message, 'all good');
      expect(tx.refunded, false);
      expect(tx.claimableBalanceId, 'cb-1');
    });

    test('leaves optional dates and nested objects null when absent', () {
      final anchorTx = flutter_sdk.AnchorTransaction(
        id: 'tx-2',
        kind: 'withdrawal',
        status: 'incomplete',
      );

      final tx = Sep6Transaction.fromAnchorTransaction(anchorTx);

      expect(tx.id, 'tx-2');
      expect(tx.kind, 'withdrawal');
      expect(tx.status.value, 'incomplete');
      expect(tx.startedAt, isNull);
      expect(tx.updatedAt, isNull);
      expect(tx.completedAt, isNull);
      expect(tx.userActionRequiredBy, isNull);
      expect(tx.chargedFeeInfo, isNull);
      expect(tx.refunds, isNull);
      expect(tx.requiredInfoUpdates, isNull);
      expect(tx.instructions, isNull);
    });

    test('maps nested feeDetails into Sep6ChargedFee with detail breakdown', () {
      final anchorTx = flutter_sdk.AnchorTransaction(
        id: 'tx-3',
        kind: 'deposit',
        status: 'pending_anchor',
        feeDetails: flutter_sdk.FeeDetails(
          '5.00',
          'iso4217:USD',
          details: [
            flutter_sdk.FeeDetailsDetails('ACH fee', '3.00',
                description: 'Bank settlement'),
            flutter_sdk.FeeDetailsDetails('Service fee', '2.00'),
          ],
        ),
      );

      final tx = Sep6Transaction.fromAnchorTransaction(anchorTx);

      expect(tx.chargedFeeInfo, isNotNull);
      expect(tx.chargedFeeInfo!.total, '5.00');
      expect(tx.chargedFeeInfo!.asset, 'iso4217:USD');
      expect(tx.chargedFeeInfo!.details, isNotNull);
      expect(tx.chargedFeeInfo!.details!.length, 2);
      expect(tx.chargedFeeInfo!.details![0].name, 'ACH fee');
      expect(tx.chargedFeeInfo!.details![0].amount, '3.00');
      expect(tx.chargedFeeInfo!.details![0].description, 'Bank settlement');
      expect(tx.chargedFeeInfo!.details![1].name, 'Service fee');
      expect(tx.chargedFeeInfo!.details![1].amount, '2.00');
      expect(tx.chargedFeeInfo!.details![1].description, isNull);
    });

    test('maps feeDetails with no detail breakdown', () {
      final anchorTx = flutter_sdk.AnchorTransaction(
        id: 'tx-4',
        kind: 'deposit',
        status: 'pending_anchor',
        feeDetails: flutter_sdk.FeeDetails('1.50', 'iso4217:USD'),
      );

      final tx = Sep6Transaction.fromAnchorTransaction(anchorTx);

      expect(tx.chargedFeeInfo, isNotNull);
      expect(tx.chargedFeeInfo!.total, '1.50');
      expect(tx.chargedFeeInfo!.asset, 'iso4217:USD');
      expect(tx.chargedFeeInfo!.details, isNull);
    });

    test('maps refunds with payments', () {
      final anchorTx = flutter_sdk.AnchorTransaction(
        id: 'tx-5',
        kind: 'deposit',
        status: 'refunded',
        refunded: true,
        refunds: flutter_sdk.TransactionRefunds(
          '95.00',
          '1.00',
          [
            flutter_sdk.TransactionRefundPayment(
                'payment-1', 'stellar', '50.00', '0.50'),
            flutter_sdk.TransactionRefundPayment(
                'payment-2', 'external', '45.00', '0.50'),
          ],
        ),
      );

      final tx = Sep6Transaction.fromAnchorTransaction(anchorTx);

      expect(tx.refunded, true);
      expect(tx.refunds, isNotNull);
      expect(tx.refunds!.amountRefunded, '95.00');
      expect(tx.refunds!.amountFee, '1.00');
      expect(tx.refunds!.payments.length, 2);
      expect(tx.refunds!.payments[0].id, 'payment-1');
      expect(tx.refunds!.payments[0].idType, 'stellar');
      expect(tx.refunds!.payments[0].amount, '50.00');
      expect(tx.refunds!.payments[0].fee, '0.50');
      expect(tx.refunds!.payments[1].id, 'payment-2');
      expect(tx.refunds!.payments[1].idType, 'external');
      expect(tx.refunds!.payments[1].amount, '45.00');
      expect(tx.refunds!.payments[1].fee, '0.50');
    });

    test('maps requiredInfoUpdates into Sep6FieldInfo entries', () {
      final anchorTx = flutter_sdk.AnchorTransaction(
        id: 'tx-6',
        kind: 'withdrawal',
        status: 'pending_transaction_info_update',
        requiredInfoMessage: 'We need your routing number',
        requiredInfoUpdates: {
          'routing_number': flutter_sdk.AnchorField(
              'ABA routing number', false, null),
          'account_type': flutter_sdk.AnchorField(
              'Type of bank account', true, ['checking', 'savings']),
        },
      );

      final tx = Sep6Transaction.fromAnchorTransaction(anchorTx);

      expect(tx.requiredInfoMessage, 'We need your routing number');
      expect(tx.requiredInfoUpdates, isNotNull);
      expect(tx.requiredInfoUpdates!.length, 2);

      final routing = tx.requiredInfoUpdates!['routing_number']!;
      expect(routing.description, 'ABA routing number');
      expect(routing.optional, false);
      expect(routing.choices, isNull);

      final accountType = tx.requiredInfoUpdates!['account_type']!;
      expect(accountType.description, 'Type of bank account');
      expect(accountType.optional, true);
      expect(accountType.choices, ['checking', 'savings']);
    });

    test('maps instructions into Sep6DepositInstruction entries', () {
      final anchorTx = flutter_sdk.AnchorTransaction(
        id: 'tx-7',
        kind: 'deposit',
        status: 'pending_user_transfer_start',
        instructions: {
          'organization.bank_number': flutter_sdk.DepositInstruction(
              '121122676', 'US bank routing number'),
          'organization.bank_account_number': flutter_sdk.DepositInstruction(
              '13719713158835300', 'US bank account number'),
        },
      );

      final tx = Sep6Transaction.fromAnchorTransaction(anchorTx);

      expect(tx.instructions, isNotNull);
      expect(tx.instructions!.length, 2);
      expect(tx.instructions!['organization.bank_number']!.value, '121122676');
      expect(tx.instructions!['organization.bank_number']!.description,
          'US bank routing number');
      expect(tx.instructions!['organization.bank_account_number']!.value,
          '13719713158835300');
      expect(tx.instructions!['organization.bank_account_number']!.description,
          'US bank account number');
    });
  });

  group('Sep6Info fromSep6InfoResponse Tests', () {
    test('maps deposit, withdraw, exchange assets and endpoint info', () {
      final response = flutter_sdk.InfoResponse(
        {
          'USD': flutter_sdk.DepositAsset(
            true,
            true,
            1.0,
            0.5,
            10.0,
            1000.0,
            {
              'email_address':
                  flutter_sdk.AnchorField('Email', true, null),
            },
          ),
        },
        {
          'USDC': flutter_sdk.DepositExchangeAsset(
            true,
            false,
            null,
          ),
        },
        {
          'USD': flutter_sdk.WithdrawAsset(
            true,
            null,
            2.0,
            1.0,
            5.0,
            500.0,
            {
              'bank_account': {
                'dest': flutter_sdk.AnchorField('IBAN', false, null),
              },
              'cash': null,
            },
          ),
        },
        {
          'USDC': flutter_sdk.WithdrawExchangeAsset(
            true,
            true,
            {
              'bank_account': {
                'dest': flutter_sdk.AnchorField('IBAN', false, null),
              },
            },
          ),
        },
        flutter_sdk.AnchorFeeInfo(true, false, 'Fee description'),
        flutter_sdk.AnchorTransactionsInfo(true, true),
        flutter_sdk.AnchorTransactionInfo(true, false),
        flutter_sdk.AnchorFeatureFlags(true, false),
      );

      final info = Sep6Info.fromSep6InfoResponse(response);

      // deposit
      expect(info.deposit, isNotNull);
      expect(info.deposit!['USD']!.enabled, true);
      expect(info.deposit!['USD']!.authenticationRequired, true);
      expect(info.deposit!['USD']!.feeFixed, 1.0);
      expect(info.deposit!['USD']!.feePercent, 0.5);
      expect(info.deposit!['USD']!.minAmount, 10.0);
      expect(info.deposit!['USD']!.maxAmount, 1000.0);
      expect(info.deposit!['USD']!.fieldsInfo, isNotNull);
      expect(info.deposit!['USD']!.fieldsInfo!['email_address']!.description,
          'Email');
      expect(info.deposit!['USD']!.fieldsInfo!['email_address']!.optional, true);

      // deposit-exchange
      expect(info.depositExchange, isNotNull);
      expect(info.depositExchange!['USDC']!.enabled, true);
      expect(info.depositExchange!['USDC']!.authenticationRequired, false);
      expect(info.depositExchange!['USDC']!.fieldsInfo, isNull);

      // withdraw
      expect(info.withdraw, isNotNull);
      expect(info.withdraw!['USD']!.enabled, true);
      expect(info.withdraw!['USD']!.authenticationRequired, isNull);
      expect(info.withdraw!['USD']!.feeFixed, 2.0);
      expect(info.withdraw!['USD']!.feePercent, 1.0);
      expect(info.withdraw!['USD']!.minAmount, 5.0);
      expect(info.withdraw!['USD']!.maxAmount, 500.0);
      expect(info.withdraw!['USD']!.types, isNotNull);
      expect(
          info.withdraw!['USD']!.types!['bank_account']!['dest']!.description,
          'IBAN');
      // A type with null fields should map to a null field map.
      expect(info.withdraw!['USD']!.types!.containsKey('cash'), true);
      expect(info.withdraw!['USD']!.types!['cash'], isNull);

      // withdraw-exchange
      expect(info.withdrawExchange, isNotNull);
      expect(info.withdrawExchange!['USDC']!.enabled, true);
      expect(info.withdrawExchange!['USDC']!.authenticationRequired, true);
      expect(
          info.withdrawExchange!['USDC']!
              .types!['bank_account']!['dest']!.description,
          'IBAN');

      // endpoint info
      expect(info.fee, isNotNull);
      expect(info.fee!.enabled, true);
      expect(info.fee!.authenticationRequired, false);
      expect(info.fee!.description, 'Fee description');

      expect(info.transactions, isNotNull);
      expect(info.transactions!.enabled, true);
      expect(info.transactions!.authenticationRequired, true);

      expect(info.transaction, isNotNull);
      expect(info.transaction!.enabled, true);
      expect(info.transaction!.authenticationRequired, false);

      // features
      expect(info.features, isNotNull);
      expect(info.features!.accountCreation, true);
      expect(info.features!.claimableBalances, false);
    });

    test('leaves endpoint and feature info null when response omits them', () {
      final response = flutter_sdk.InfoResponse(
        {},
        {},
        {},
        {},
        null,
        null,
        null,
        null,
      );

      final info = Sep6Info.fromSep6InfoResponse(response);

      expect(info.fee, isNull);
      expect(info.transactions, isNull);
      expect(info.transaction, isNull);
      expect(info.features, isNull);
      // Empty (non-null) asset maps round-trip to empty maps.
      expect(info.deposit, isNotNull);
      expect(info.deposit, isEmpty);
      expect(info.withdraw, isNotNull);
      expect(info.withdraw, isEmpty);
    });
  });

  group('Sep6EndpointInfo enabled defaulting Tests', () {
    test('fee info enabled defaults to false when null', () {
      final info =
          Sep6EndpointInfo.fromSep6AnchorFeeInfo(flutter_sdk.AnchorFeeInfo(
        null,
        null,
        null,
      ));

      expect(info.enabled, false);
      expect(info.authenticationRequired, isNull);
      expect(info.description, isNull);
    });

    test('transaction info enabled defaults to false when null', () {
      final info = Sep6EndpointInfo.fromSep6AnchorTransactionInfo(
          flutter_sdk.AnchorTransactionInfo(null, true));

      expect(info.enabled, false);
      expect(info.authenticationRequired, true);
    });

    test('transactions info enabled defaults to false when null', () {
      final info = Sep6EndpointInfo.fromSep6AnchorTransactionsInfo(
          flutter_sdk.AnchorTransactionsInfo(null, false));

      expect(info.enabled, false);
      expect(info.authenticationRequired, false);
    });

    test('fee info preserves enabled true', () {
      final info = Sep6EndpointInfo.fromSep6AnchorFeeInfo(
          flutter_sdk.AnchorFeeInfo(true, true, 'desc'));

      expect(info.enabled, true);
      expect(info.authenticationRequired, true);
      expect(info.description, 'desc');
    });
  });

  group('Sep6Pending fromCustomerInformationStatusResponse Tests', () {
    test('defaults status to "pending" when response status is null', () {
      final pending = Sep6Pending.fromCustomerInformationStatusResponse(
          flutter_sdk.CustomerInformationStatusResponse(
              null, 'https://anchor.example.com/info', 120));

      expect(pending.status, 'pending');
      expect(pending.moreInfoUrl, 'https://anchor.example.com/info');
      expect(pending.eta, 120);
    });

    test('preserves provided denied status', () {
      final pending = Sep6Pending.fromCustomerInformationStatusResponse(
          flutter_sdk.CustomerInformationStatusResponse('denied', null, null));

      expect(pending.status, 'denied');
      expect(pending.moreInfoUrl, isNull);
      expect(pending.eta, isNull);
    });
  });

  group('Sep6MissingKYC fromCustomerInformationNeededResponse Tests', () {
    test('defaults fields to empty list when response fields are null', () {
      final missing = Sep6MissingKYC.fromCustomerInformationNeededResponse(
          flutter_sdk.CustomerInformationNeededResponse(null));

      expect(missing.fields, isNotNull);
      expect(missing.fields, isEmpty);
    });

    test('preserves provided field names', () {
      final missing = Sep6MissingKYC.fromCustomerInformationNeededResponse(
          flutter_sdk.CustomerInformationNeededResponse(
              ['first_name', 'last_name', 'email_address']));

      expect(missing.fields, ['first_name', 'last_name', 'email_address']);
    });
  });

  group('Sep6WithdrawSuccess fromWithdrawResponse Tests', () {
    test('maps all scalar fields', () {
      final response = flutter_sdk.WithdrawResponse(
        'GANCHORWITHDRAWXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        'id',
        '987654',
        'withdraw-id-1',
        300,
        5.0,
        2000.0,
        1.5,
        0.25,
        null,
      );

      final success = Sep6WithdrawSuccess.fromWithdrawResponse(response);

      expect(success.accountId,
          'GANCHORWITHDRAWXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
      expect(success.memoType, 'id');
      expect(success.memo, '987654');
      expect(success.id, 'withdraw-id-1');
      expect(success.eta, 300);
      expect(success.minAmount, 5.0);
      expect(success.maxAmount, 2000.0);
      expect(success.feeFixed, 1.5);
      expect(success.feePercent, 0.25);
      expect(success.extraInfo, isNull);
    });

    // Regression guard: when the response carries extraInfo, the mapped
    // Sep6WithdrawSuccess must expose that extraInfo (and its message).
    test('populates extraInfo when present in the response', () {
      final response = flutter_sdk.WithdrawResponse(
        'GANCHOR',
        'text',
        'memo',
        'withdraw-id-2',
        null,
        null,
        null,
        null,
        null,
        flutter_sdk.ExtraInfo('Send funds to the listed account'),
      );

      final success = Sep6WithdrawSuccess.fromWithdrawResponse(response);

      expect(success.extraInfo, isNotNull);
      expect(success.extraInfo!.message, 'Send funds to the listed account');
    });
  });

  group('Sep6DepositSuccess fromDepositResponse Tests', () {
    test('maps scalar fields and instructions', () {
      final response = flutter_sdk.DepositResponse(
        'send to address X',
        'deposit-id-1',
        450,
        1.0,
        5000.0,
        0.75,
        0.1,
        null,
        {
          'organization.bank_number': flutter_sdk.DepositInstruction(
              '121122676', 'US bank routing number'),
        },
      );

      final success = Sep6DepositSuccess.fromDepositResponse(response);

      expect(success.how, 'send to address X');
      expect(success.id, 'deposit-id-1');
      expect(success.eta, 450);
      expect(success.minAmount, 1.0);
      expect(success.feeFixed, 0.75);
      expect(success.feePercent, 0.1);
      expect(success.instructions, isNotNull);
      expect(success.instructions!.length, 1);
      expect(success.instructions!['organization.bank_number']!.value,
          '121122676');
      expect(success.instructions!['organization.bank_number']!.description,
          'US bank routing number');
    });

    // Regression guard: when the response carries extraInfo, the mapped
    // Sep6DepositSuccess must expose that extraInfo (and its message).
    test('populates extraInfo when present in the response', () {
      final response = flutter_sdk.DepositResponse(
        null,
        'deposit-id-2',
        null,
        null,
        null,
        null,
        null,
        flutter_sdk.ExtraInfo('Deposit may take up to 1 business day'),
        null,
      );

      final success = Sep6DepositSuccess.fromDepositResponse(response);

      expect(success.extraInfo, isNotNull);
      expect(success.extraInfo!.message,
          'Deposit may take up to 1 business day');
    });

    // Regression guard: maxAmount from the response must be carried through to
    // the mapped Sep6DepositSuccess.
    test('populates maxAmount when present in the response', () {
      final response = flutter_sdk.DepositResponse(
        null,
        'deposit-id-3',
        null,
        1.0,
        5000.0,
        null,
        null,
        null,
        null,
      );

      final success = Sep6DepositSuccess.fromDepositResponse(response);

      expect(success.minAmount, 1.0);
      expect(success.maxAmount, 5000.0);
    });
  });

  group('Sep6.getTransactionBy validation Tests', () {
    test('throws ValidationException when no identifier is provided', () {
      final sep6 = Wallet.testNet.anchor('place.domain.com').sep6();
      final authToken = AuthToken(_testJwt({
        'sub': 'GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN',
        'exp': 9999999999,
      }));
      // All of id/stellarTransactionId/externalTransactionId are null, so the
      // guard rejects the call before any network access.
      expect(
        sep6.getTransactionBy(authToken: authToken),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
