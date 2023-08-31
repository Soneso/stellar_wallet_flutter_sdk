// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/asset/asset_id.dart';
import 'package:http/http.dart' as http;

class AnchorErrorResponse {
  String error;
  AnchorErrorResponse(this.error);
}

class WalletException implements Exception {
  Exception? cause;
  String message;

  WalletException(this.message, {this.cause}) : super();
}

class AnchorRequestException implements WalletException {
  AnchorRequestException(this.message, {this.cause}) : super();

  @override
  Exception? cause;

  @override
  String message;
}

class HorizonRequestFailedException implements WalletException {
  @override
  Exception? cause;

  @override
  late String message;

  flutter_sdk.ErrorResponse response;

  late int errorCode;

  HorizonRequestFailedException(this.response) : super() {
    message = response.body;
    errorCode = response.code;
  }
}

// validation exceptions

class ValidationException implements WalletException {
  @override
  Exception? cause;

  @override
  String message;

  ValidationException(this.message, {this.cause}) : super();
}

class ClientDomainWithMemoException implements ValidationException {
  @override
  Exception? cause;

  @override
  late String message;

  ClientDomainWithMemoException() : super() {
    message = "Client domain cannot be used with memo";
  }
}

class InvalidAnchorServiceUrl implements ValidationException {
  @override
  Exception? cause;

  @override
  late String message;

  Exception e;
  InvalidAnchorServiceUrl(this.e) : super() {
    message = "Anchor service URL is invalid";
  }
}

class InvalidMemoIdException implements ValidationException {
  @override
  Exception? cause;

  @override
  late String message;

  InvalidMemoIdException() : super() {
    message = "Memo ID must be a positive integer";
  }
}

class InvalidStartingBalanceException implements ValidationException {
  @override
  Exception? cause;

  @override
  late String message;

  InvalidStartingBalanceException() : super() {
    message =
        "Starting balance must be at least 1 XLM for non-sponsored accounts";
  }
}

class InvalidSponsoredAccountException implements ValidationException {
  @override
  Exception? cause;

  @override
  late String message;

  InvalidSponsoredAccountException() : super() {
    message =
        "No other operations are allowed with create account operation per sponsoring block";
  }
}

// Invalid response from server

class InvalidResponseException implements WalletException {
  @override
  Exception? cause;

  @override
  String message;

  InvalidResponseException(this.message) : super();
}

class MissingTokenException implements InvalidResponseException {
  @override
  Exception? cause;

  @override
  late String message;

  MissingTokenException() : super() {
    message = "Token was not returned";
  }
}

class MissingTransactionException implements InvalidResponseException {
  @override
  Exception? cause;

  @override
  late String message;

  MissingTransactionException() : super() {
    message = "The response did not contain a transaction";
  }
}

class NetworkMismatchException implements InvalidResponseException {
  @override
  Exception? cause;

  @override
  late String message;

  NetworkMismatchException() : super() {
    message = "Networks don't match";
  }
}

class InvalidDataException implements InvalidResponseException {
  @override
  Exception? cause;

  @override
  String message;

  InvalidDataException(this.message) : super();
}

class InvalidJsonException implements InvalidResponseException {
  @override
  Exception? cause;

  @override
  late String message;

  String reason;
  dynamic json;

  InvalidJsonException(this.reason, this.json) : super() {
    message = "Invalid json response object: $reason. Json: $json";
  }
}

// stellar exceptions

class StellarException implements WalletException {
  @override
  Exception? cause;

  @override
  String message;

  StellarException(this.message, {this.cause}) : super();
}

class AccountNotEnoughBalanceException implements StellarException {
  @override
  Exception? cause;

  @override
  late String message;

  String accountAddress;
  BigInt accountBalance;
  BigInt transactionFees;

  AccountNotEnoughBalanceException(
      this.accountAddress, this.accountBalance, this.transactionFees)
      : super() {
    message =
        "Source account $accountAddress does not have enough XLM balance to "
        "cover ${transactionFees.toString()} XLM fees. "
        "Available balance ${accountBalance.toString()} XLM.";
  }
}

class TransactionSubmitFailedException implements StellarException {
  @override
  Exception? cause;

  @override
  late String message;

  flutter_sdk.SubmitTransactionResponse response;
  String? transactionResultCode;
  List<String>? operationsResultCodes;

  TransactionSubmitFailedException(this.response) : super() {
    transactionResultCode = response.extras?.resultCodes?.transactionResultCode;
    String tResCode =
        transactionResultCode != null ? transactionResultCode! : "<unknown>";
    message = "Submit transaction failed with code $tResCode.";

    if (response.extras?.resultCodes?.operationsResultCodes != null) {
      List<String?> opResCodes =
          response.extras!.resultCodes!.operationsResultCodes!;
      operationsResultCodes = List<String>.empty(growable: true);
      for (String? opReCode in opResCodes) {
        if (opReCode != null) {
          operationsResultCodes!.add(opReCode);
        }
      }
      if (operationsResultCodes!.isEmpty) {
        operationsResultCodes = null;
      } else {
        String codes = operationsResultCodes!.join(",");
        message += "Operation result codes: $codes.";
      }
    }
  }
}

class OperationsLimitExceededException implements StellarException {
  @override
  Exception? cause;

  @override
  late String message;

  OperationsLimitExceededException() : super() {
    message = "Maximum limit is 200 operations";
  }
}

// recovery exceptions

class RecoveryException implements WalletException {
  @override
  Exception? cause;

  @override
  String message;

  RecoveryException(this.message) : super();
}

class NoAccountSignersException implements RecoveryException {
  @override
  Exception? cause;

  @override
  late String message;

  NoAccountSignersException() : super() {
    message = "There are no signers on this recovery server";
  }
}

class NotAllSignaturesFetchedException implements RecoveryException {
  @override
  Exception? cause;

  @override
  late String message;

  NotAllSignaturesFetchedException() : super() {
    message = "Didn't get all recovery server signatures";
  }
}

class NotRegisteredWithAllException implements RecoveryException {
  @override
  Exception? cause;

  @override
  late String message;

  NotRegisteredWithAllException() : super() {
    message = "Could not register with all recovery servers";
  }
}

// customer exceptions

class CustomerException implements WalletException {
  @override
  Exception? cause;

  @override
  String message;

  CustomerException(this.message) : super();
}

class CustomerUpdateException implements CustomerException {
  @override
  Exception? cause;

  @override
  late String message;

  CustomerUpdateException() : super() {
    message = "At least one SEP9 field should be updated";
  }
}

class UnauthorizedCustomerDeletionException implements CustomerException {
  @override
  Exception? cause;

  @override
  late String message;

  String account;

  UnauthorizedCustomerDeletionException(this.account) : super() {
    message = "Unauthorized to delete customer account $account";
  }
}

class CustomerNotFoundException implements CustomerException {
  @override
  Exception? cause;

  @override
  late String message;

  String account;

  CustomerNotFoundException(this.account) : super() {
    message = "Customer not found for account $account";
  }
}

class ErrorOnDeletingCustomerException implements CustomerException {
  @override
  Exception? cause;

  @override
  late String message;

  String account;

  ErrorOnDeletingCustomerException(this.account) : super() {
    message = "Error on deleting customer for account $account";
  }
}

class KYCServerNotFoundException implements CustomerException {
  @override
  Exception? cause;

  @override
  late String message;

  KYCServerNotFoundException() : super() {
    message = "Required KYC server URL not found";
  }
}

// anchor exceptions

class AnchorException implements WalletException {
  @override
  Exception? cause;

  @override
  String message;

  AnchorException(this.message) : super();
}

class AnchorAssetException implements AnchorException {
  @override
  Exception? cause;

  @override
  String message;

  AnchorAssetException(this.message) : super();
}

class AnchorTransactionNotFoundException implements AnchorException {
  @override
  Exception? cause;

  @override
  String message;

  AnchorTransactionNotFoundException(this.message, this.cause) : super();
}

class AnchorAuthException implements AnchorException {
  @override
  Exception? cause;

  @override
  String message;

  AnchorAuthException(this.message, this.cause) : super();
}

class AssetNotAcceptedForDepositException implements AnchorAssetException {
  @override
  Exception? cause;

  @override
  late String message;

  StellarAssetId assetId;

  AssetNotAcceptedForDepositException(this.assetId) : super() {
    String strId = assetId.sep38;
    message = "Asset $strId is not accepted for deposits";
  }
}

class AssetNotAcceptedForWithdrawalException implements AnchorAssetException {
  @override
  Exception? cause;

  @override
  late String message;

  StellarAssetId assetId;

  AssetNotAcceptedForWithdrawalException(this.assetId) : super() {
    String strId = assetId.sep38;
    message = "Asset $strId is not accepted for withdrawals";
  }
}

class AssetNotEnabledForDepositException implements AnchorAssetException {
  @override
  Exception? cause;

  @override
  late String message;

  StellarAssetId assetId;

  AssetNotEnabledForDepositException(this.assetId) : super() {
    String strId = assetId.sep38;
    message = "Asset $strId is not enabled for deposits";
  }
}

class AssetNotEnabledForWithdrawalException implements AnchorAssetException {
  @override
  Exception? cause;

  @override
  late String message;

  StellarAssetId assetId;

  AssetNotEnabledForWithdrawalException(this.assetId) : super() {
    String strId = assetId.sep38;
    message = "Asset $strId is not enabled for withdrawals";
  }
}

class AssetNotSupportedException implements AnchorAssetException {
  @override
  Exception? cause;

  @override
  late String message;

  AssetId assetId;

  AssetNotSupportedException(this.assetId) : super() {
    String strId = assetId.sep38;
    message = "Asset $strId is not supported";
  }
}
// TODO
/*
class IncorrectTransactionStatusException implements WalletException {
  @override
  Exception? cause;

  @override
  late String message;


}*/

class AnchorAuthNotSupported implements AnchorException {
  @override
  Exception? cause;

  @override
  late String message;

  AnchorAuthNotSupported() : super() {
    message = "Anchor does not have SEP-10 auth configured in TOML file";
  }
}

class AnchorInteractiveFlowNotSupported implements AnchorException {
  @override
  Exception? cause;

  @override
  late String message;

  AnchorInteractiveFlowNotSupported() : super() {
    message =
        "Anchor does not have SEP-24 interactive flow configured in TOML file";
  }
}

class TomlNotFoundException implements AnchorException {
  @override
  Exception? cause;

  @override
  late String message;

  TomlNotFoundException(String? msg) : super() {
    if (msg != null) {
      message = msg;
    } else {
      message = "Stellar TOML not found";
    }
  }
}

class DomainSignerUnexpectedResponseException implements Exception {
  final http.Response response;

  DomainSignerUnexpectedResponseException(this.response);

  @override
  String toString() {
    String code = response.statusCode.toString();
    String body = response.body;
    return "Unknown response from Domain signer - code: $code - body:$body";
  }
}
