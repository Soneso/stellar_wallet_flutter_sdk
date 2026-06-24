// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/stellar_wallet_flutter_sdk.dart';

/// Builds a [flutter_sdk.SubmitTransactionResponse] whose only meaningful
/// content is the [flutter_sdk.ExtrasResultCodes] under
/// `extras.resultCodes`. All XDR-bearing fields are left empty / null because
/// [TransactionSubmitFailedException] only reads the result codes.
flutter_sdk.SubmitTransactionResponse _responseWithResultCodes(
    flutter_sdk.ExtrasResultCodes? resultCodes) {
  final extras = flutter_sdk.SubmitTransactionResponseExtras(
    "", // envelopeXdr
    "", // resultXdr
    null, // strMetaXdr
    null, // strFeeMetaXdr
    resultCodes,
  );
  return flutter_sdk.SubmitTransactionResponse(
    extras,
    null, // ledger
    null, // hash
    null, // _strEnvelopeXdr
    null, // _strResultXdr
    null, // _strMetaXdr
    null, // _strFeeMetaXdr
    null, // successfulTransaction
  );
}

/// Builds a [flutter_sdk.SubmitTransactionResponse] with a null `extras`.
flutter_sdk.SubmitTransactionResponse _responseWithNullExtras() {
  return flutter_sdk.SubmitTransactionResponse(
    null, // extras
    null, // ledger
    null, // hash
    null, // _strEnvelopeXdr
    null, // _strResultXdr
    null, // _strMetaXdr
    null, // _strFeeMetaXdr
    null, // successfulTransaction
  );
}

void main() {
  group('Validation Exception Tests', () {
    test('InvalidStartingBalanceException has fixed message', () {
      final e = InvalidStartingBalanceException();
      expect(
          e.message,
          "Starting balance must be at least 1 XLM for non-sponsored accounts "
          "and at least 0 XLM for sponsored accounts");
      expect(e.cause, isNull);
    });

    test('PathPayOnlyOneAmountException has fixed message', () {
      final e = PathPayOnlyOneAmountException();
      expect(e.message, "Must give sendAmount or destAmount value, but not both.");
    });

    test('ClientDomainWithMemoException has fixed message', () {
      final e = ClientDomainWithMemoException();
      expect(e.message, "Client domain cannot be used with memo");
    });

    test('InvalidMemoIdException has fixed message', () {
      final e = InvalidMemoIdException();
      expect(e.message, "Memo ID must be a positive integer");
    });

    test('InvalidSponsoredAccountException has fixed message', () {
      final e = InvalidSponsoredAccountException();
      expect(
          e.message,
          "No other operations are allowed with create account operation per "
          "sponsoring block");
    });

    test('InvalidAnchorServiceUrl exposes underlying exception and fixed message',
        () {
      final inner = FormatException("bad url");
      final e = InvalidAnchorServiceUrl(inner);
      expect(e.message, "Anchor service URL is invalid");
      expect(e.e, same(inner));
    });

    test('OperationsLimitExceededException has fixed message', () {
      final e = OperationsLimitExceededException();
      expect(e.message, "Maximum limit is 200 operations");
    });
  });

  group('InvalidResponseException Tests', () {
    test('MissingTokenException has fixed message', () {
      final e = MissingTokenException();
      expect(e.message, "Token was not returned");
    });

    test('MissingTransactionException has fixed message', () {
      final e = MissingTransactionException();
      expect(e.message, "The response did not contain a transaction");
    });

    test('NetworkMismatchException has fixed message', () {
      final e = NetworkMismatchException();
      expect(e.message, "Networks don't match");
    });

    test('InvalidDataException carries provided message', () {
      final e = InvalidDataException("something is wrong");
      expect(e.message, "something is wrong");
    });

    test('InvalidJsonException interpolates reason and json', () {
      final json = {"a": 1, "b": "two"};
      final e = InvalidJsonException("unexpected token", json);
      expect(e.reason, "unexpected token");
      expect(e.json, same(json));
      expect(e.message,
          "Invalid json response object: unexpected token. Json: $json");
    });

    test('InvalidJsonException tolerates null json', () {
      final e = InvalidJsonException("empty body", null);
      expect(e.message,
          "Invalid json response object: empty body. Json: null");
    });
  });

  group('StellarException Tests', () {
    test(
        'AccountNotEnoughBalanceException interpolates address, balance and fees',
        () {
      final e = AccountNotEnoughBalanceException(
        "GABC",
        BigInt.from(100),
        BigInt.from(250),
      );
      expect(e.accountAddress, "GABC");
      expect(e.accountBalance, BigInt.from(100));
      expect(e.transactionFees, BigInt.from(250));
      expect(
          e.message,
          "Source account GABC does not have enough XLM balance to cover 250 "
          "XLM fees. Available balance 100 XLM.");
    });

    test(
        'AccountNotEnoughBalanceException handles int64 boundary BigInt values',
        () {
      // int64 max and min stored as raw stroop amounts.
      final maxInt64 = BigInt.parse("9223372036854775807");
      final minInt64 = BigInt.parse("-9223372036854775808");
      final e = AccountNotEnoughBalanceException(
        "GXYZ",
        maxInt64,
        minInt64,
      );
      expect(e.accountBalance, maxInt64);
      expect(e.transactionFees, minInt64);
      expect(
          e.message,
          "Source account GXYZ does not have enough XLM balance to cover "
          "-9223372036854775808 XLM fees. "
          "Available balance 9223372036854775807 XLM.");
    });

    test(
        'AccountNotEnoughBalanceException handles values beyond int64 range',
        () {
      // BigInt has no 64-bit limit; values larger than int64 must render fully.
      final huge = BigInt.parse("92233720368547758070000");
      final e = AccountNotEnoughBalanceException("GHUGE", huge, huge);
      expect(
          e.message,
          "Source account GHUGE does not have enough XLM balance to cover "
          "92233720368547758070000 XLM fees. "
          "Available balance 92233720368547758070000 XLM.");
    });
  });

  group('TransactionSubmitFailedException Tests', () {
    test('null extras yields <unknown> transaction code and no operation codes',
        () {
      final e = TransactionSubmitFailedException(_responseWithNullExtras());
      expect(e.transactionResultCode, isNull);
      expect(e.operationsResultCodes, isNull);
      expect(e.message, "Submit transaction failed with code <unknown>.");
    });

    test('extras present but resultCodes null yields <unknown> code', () {
      final e = TransactionSubmitFailedException(
          _responseWithResultCodes(null));
      expect(e.transactionResultCode, isNull);
      expect(e.operationsResultCodes, isNull);
      expect(e.message, "Submit transaction failed with code <unknown>.");
    });

    test('transactionResultCode is extracted into the message', () {
      final e = TransactionSubmitFailedException(_responseWithResultCodes(
          flutter_sdk.ExtrasResultCodes("tx_failed", null)));
      expect(e.transactionResultCode, "tx_failed");
      expect(e.operationsResultCodes, isNull);
      expect(e.message, "Submit transaction failed with code tx_failed.");
    });

    test('operationsResultCodes containing only nulls is treated as empty', () {
      final e = TransactionSubmitFailedException(_responseWithResultCodes(
          flutter_sdk.ExtrasResultCodes("tx_failed", [null, null])));
      // After filtering out the nulls nothing remains, so it is reset to null
      // and the message must not gain an operation-codes suffix.
      expect(e.operationsResultCodes, isNull);
      expect(e.message, "Submit transaction failed with code tx_failed.");
    });

    test('empty operationsResultCodes list produces no operation-codes suffix',
        () {
      final e = TransactionSubmitFailedException(_responseWithResultCodes(
          flutter_sdk.ExtrasResultCodes("tx_failed", <String?>[])));
      expect(e.operationsResultCodes, isNull);
      expect(e.message, "Submit transaction failed with code tx_failed.");
    });

    test('mixed null and non-null operation codes are filtered, preserving order',
        () {
      final e = TransactionSubmitFailedException(_responseWithResultCodes(
          flutter_sdk.ExtrasResultCodes(
              "tx_failed", ["op_underfunded", null, "op_no_destination"])));
      // Only the non-null codes survive, original relative order preserved.
      expect(e.operationsResultCodes,
          ["op_underfunded", "op_no_destination"]);
    });

    test('single non-null operation code is joined into the message', () {
      final e = TransactionSubmitFailedException(_responseWithResultCodes(
          flutter_sdk.ExtrasResultCodes("tx_failed", ["op_underfunded"])));
      expect(e.operationsResultCodes, ["op_underfunded"]);
      // Asserts the CORRECT message with a separator between the sentence and
      // the operation result codes. Source builds this WITHOUT a separator
      // (exceptions.dart:271-272), so this test reveals that defect.
      expect(
          e.message,
          "Submit transaction failed with code tx_failed. "
          "Operation result codes: op_underfunded.");
    });

    test('multiple non-null operation codes are comma-joined into the message',
        () {
      final e = TransactionSubmitFailedException(_responseWithResultCodes(
          flutter_sdk.ExtrasResultCodes(
              "tx_failed", ["op_underfunded", "op_no_destination"])));
      expect(e.operationsResultCodes,
          ["op_underfunded", "op_no_destination"]);
      // Asserts the CORRECT, separated message. Reveals the missing separator
      // defect at exceptions.dart:271-272.
      expect(
          e.message,
          "Submit transaction failed with code tx_failed. "
          "Operation result codes: op_underfunded,op_no_destination.");
    });
  });

  group('Recovery Exception Tests', () {
    test('NoAccountSignersException has fixed message', () {
      expect(NoAccountSignersException().message,
          "There are no signers on this recovery server");
    });

    test('NotAllSignaturesFetchedException has fixed message', () {
      expect(NotAllSignaturesFetchedException().message,
          "Didn't get all recovery server signatures");
    });

    test('NotRegisteredWithAllException has fixed message', () {
      expect(NotRegisteredWithAllException().message,
          "Could not register with all recovery servers");
    });

    test('Sep10AuthNotSupported carries message and cause', () {
      final cause = InvalidMemoIdException();
      final e = Sep10AuthNotSupported("no auth", cause: cause);
      expect(e.message, "no auth");
      expect(e.cause, same(cause));
    });

    test('RecoveryServerResponseError carries message', () {
      final e = RecoveryServerResponseError("server error");
      expect(e.message, "server error");
      expect(e.cause, isNull);
    });
  });

  group('Customer Exception Tests', () {
    test('CustomerUpdateException has fixed message', () {
      expect(CustomerUpdateException().message,
          "At least one SEP9 field should be updated");
    });

    test('UnauthorizedCustomerDeletionException interpolates account', () {
      final e = UnauthorizedCustomerDeletionException("GACCOUNT123");
      expect(e.account, "GACCOUNT123");
      expect(e.message,
          "Unauthorized to delete customer account GACCOUNT123");
    });

    test('CustomerNotFoundException interpolates account', () {
      final e = CustomerNotFoundException("GACCOUNT123");
      expect(e.account, "GACCOUNT123");
      expect(e.message, "Customer not found for account GACCOUNT123");
    });

    test('ErrorOnDeletingCustomerException interpolates account', () {
      final e = ErrorOnDeletingCustomerException("GACCOUNT123");
      expect(e.account, "GACCOUNT123");
      expect(e.message, "Error on deleting customer for account GACCOUNT123");
    });

    test('KYCServerNotFoundException has fixed message', () {
      expect(KYCServerNotFoundException().message,
          "Required KYC server URL not found");
    });

    test('AnchorQuoteServerNotFoundException has fixed message', () {
      expect(AnchorQuoteServerNotFoundException().message,
          "Required Anchor Quote Server URL not found");
    });
  });

  group('Asset Exception Tests', () {
    late IssuedAssetId issued;
    late NativeAssetId native;
    late FiatAssetId fiat;

    setUp(() {
      issued = IssuedAssetId(
          code: "USDC",
          issuer:
              "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM");
      native = NativeAssetId();
      fiat = FiatAssetId("USD");
    });

    test('AssetNotAcceptedForDepositException uses assetId.sep38', () {
      final e = AssetNotAcceptedForDepositException(issued);
      expect(e.assetId, same(issued));
      expect(
          e.message,
          "Asset stellar:USDC:"
          "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM "
          "is not accepted for deposits");
    });

    test('AssetNotAcceptedForWithdrawalException uses assetId.sep38', () {
      final e = AssetNotAcceptedForWithdrawalException(native);
      expect(e.message, "Asset stellar:native is not accepted for withdrawals");
    });

    test('AssetNotEnabledForDepositException uses assetId.sep38', () {
      final e = AssetNotEnabledForDepositException(native);
      expect(e.message, "Asset stellar:native is not enabled for deposits");
    });

    test('AssetNotEnabledForWithdrawalException uses assetId.sep38', () {
      final e = AssetNotEnabledForWithdrawalException(issued);
      expect(
          e.message,
          "Asset stellar:USDC:"
          "GCZJM35NKGVK47BB4SPBDV25477PZYIYPVVG453LPYFNXLS3FGHDXOCM "
          "is not enabled for withdrawals");
    });

    test('AssetNotSupportedException uses assetId.sep38 for a fiat asset', () {
      final e = AssetNotSupportedException(fiat);
      expect(e.message, "Asset iso4217:USD is not supported");
    });

    test('AssetNotSupportedException uses assetId.sep38 for a native asset', () {
      final e = AssetNotSupportedException(native);
      expect(e.message, "Asset stellar:native is not supported");
    });
  });

  group('Anchor Exception Tests', () {
    test('AnchorAuthNotSupported has fixed message', () {
      expect(AnchorAuthNotSupported().message,
          "Anchor does not have SEP-10 auth configured in TOML file");
    });

    test('AnchorInteractiveFlowNotSupported has fixed message', () {
      expect(
          AnchorInteractiveFlowNotSupported().message,
          "Anchor does not have SEP-24 interactive flow configured in TOML "
          "file");
    });

    test('AnchorDepositAndWithdrawalAPINotSupported has fixed message', () {
      expect(
          AnchorDepositAndWithdrawalAPINotSupported().message,
          "Anchor does not have SEP-06 Deposit and Withdrawal API configured "
          "in TOML file");
    });

    test('TomlNotFoundException uses default message when null is passed', () {
      final e = TomlNotFoundException(null);
      expect(e.message, "Stellar TOML not found");
    });

    test('TomlNotFoundException uses provided message when non-null', () {
      final e = TomlNotFoundException("custom toml error");
      expect(e.message, "custom toml error");
    });

    test('AnchorTransactionNotFoundException carries message and cause', () {
      final cause = FormatException("nope");
      final e = AnchorTransactionNotFoundException("not found", cause);
      expect(e.message, "not found");
      expect(e.cause, same(cause));
    });

    test('BadRequestDataException carries message with optional cause', () {
      final e = BadRequestDataException("bad data");
      expect(e.message, "bad data");
      expect(e.cause, isNull);
    });

    test('AnchorAuthException carries message and cause', () {
      final cause = FormatException("auth failed");
      final e = AnchorAuthException("auth error", cause);
      expect(e.message, "auth error");
      expect(e.cause, same(cause));
    });
  });

  group('HorizonRequestFailedException Tests', () {
    test('derives message and errorCode from the ErrorResponse', () {
      final httpResponse = http.Response("the error body", 404);
      final errorResponse = flutter_sdk.ErrorResponse(httpResponse);
      final e = HorizonRequestFailedException(errorResponse);
      expect(e.response, same(errorResponse));
      expect(e.message, "the error body");
      expect(e.errorCode, 404);
    });
  });

  group('DomainSignerUnexpectedResponseException Tests', () {
    test('toString interpolates status code and body', () {
      final response = http.Response("internal error", 500);
      final e = DomainSignerUnexpectedResponseException(response);
      expect(e.response, same(response));
      expect(e.toString(),
          "Unknown response from Domain signer - code: 500 - body:internal error");
    });

    test('toString reflects an empty body', () {
      final response = http.Response("", 401);
      final e = DomainSignerUnexpectedResponseException(response);
      expect(e.toString(),
          "Unknown response from Domain signer - code: 401 - body:");
    });
  });

  group('Sep7 and Quote Exception Tests', () {
    test('Sep7Exception carries message', () {
      final e = Sep7Exception("sep7 problem");
      expect(e.message, "sep7 problem");
    });

    test('UnsupportedSep7OperationType carries message and cause', () {
      final cause = FormatException("bad op");
      final e = UnsupportedSep7OperationType("unsupported op", cause: cause);
      expect(e.message, "unsupported op");
      expect(e.cause, same(cause));
    });

    test('Sep7MsgTooLong carries message', () {
      final e = Sep7MsgTooLong("too long");
      expect(e.message, "too long");
    });

    test('Sep7InvalidUri carries message', () {
      final e = Sep7InvalidUri("invalid uri");
      expect(e.message, "invalid uri");
    });

    test('Sep7UriTypeNotSupported carries message', () {
      final e = Sep7UriTypeNotSupported("uri type unsupported");
      expect(e.message, "uri type unsupported");
    });

    test('QuoteEndpointAuthRequired carries message and cause', () {
      final cause = FormatException("auth");
      final e = QuoteEndpointAuthRequired("auth required", cause: cause);
      expect(e.message, "auth required");
      expect(e.cause, same(cause));
    });

    test('QuoteRequestPermissionDenied carries message', () {
      final e = QuoteRequestPermissionDenied("denied");
      expect(e.message, "denied");
    });
  });

  group('Type Hierarchy Tests', () {
    test('MissingTokenException is an InvalidResponseException and WalletException',
        () {
      final e = MissingTokenException();
      expect(e, isA<MissingTokenException>());
      expect(e, isA<InvalidResponseException>());
      expect(e, isA<WalletException>());
      expect(e, isA<Exception>());
    });

    test('InvalidJsonException is an InvalidResponseException', () {
      final e = InvalidJsonException("r", null);
      expect(e, isA<InvalidResponseException>());
      expect(e, isA<WalletException>());
    });

    test('AccountNotEnoughBalanceException is a StellarException', () {
      final e =
          AccountNotEnoughBalanceException("G", BigInt.zero, BigInt.zero);
      expect(e, isA<StellarException>());
      expect(e, isA<WalletException>());
    });

    test('TransactionSubmitFailedException is a StellarException', () {
      final e = TransactionSubmitFailedException(_responseWithNullExtras());
      expect(e, isA<StellarException>());
      expect(e, isA<WalletException>());
    });

    test('Validation exceptions implement ValidationException and WalletException',
        () {
      expect(InvalidStartingBalanceException(), isA<ValidationException>());
      expect(InvalidStartingBalanceException(), isA<WalletException>());
      expect(Sep7MsgTooLong("x"), isA<ValidationException>());
      expect(Sep7InvalidUri("x"), isA<ValidationException>());
      expect(Sep7UriTypeNotSupported("x"), isA<ValidationException>());
    });

    test('Customer exceptions implement CustomerException and WalletException',
        () {
      expect(CustomerUpdateException(), isA<CustomerException>());
      expect(CustomerNotFoundException("a"), isA<CustomerException>());
      expect(KYCServerNotFoundException(), isA<WalletException>());
    });

    test('Asset exceptions implement AnchorAssetException and AnchorException',
        () {
      final e = AssetNotSupportedException(NativeAssetId());
      expect(e, isA<AnchorAssetException>());
      expect(e, isA<AnchorException>());
      expect(e, isA<WalletException>());
    });

    test('Recovery exceptions implement RecoveryException and WalletException',
        () {
      expect(NoAccountSignersException(), isA<RecoveryException>());
      expect(NoAccountSignersException(), isA<WalletException>());
    });

    test('Quote exceptions implement QuoteException and WalletException', () {
      expect(QuoteRequestPermissionDenied("x"), isA<QuoteException>());
      expect(QuoteEndpointAuthRequired("x"), isA<WalletException>());
    });

    test('Sep7 exceptions implement WalletException', () {
      expect(Sep7Exception("x"), isA<WalletException>());
      expect(UnsupportedSep7OperationType("x"), isA<Sep7Exception>());
    });

    test('DomainSignerUnexpectedResponseException is an Exception but not a '
        'WalletException', () {
      final e = DomainSignerUnexpectedResponseException(http.Response("", 200));
      expect(e, isA<Exception>());
      expect(e, isNot(isA<WalletException>()));
    });

    test('HorizonRequestFailedException is a WalletException', () {
      final e = HorizonRequestFailedException(
          flutter_sdk.ErrorResponse(http.Response("", 500)));
      expect(e, isA<WalletException>());
    });
  });
}
