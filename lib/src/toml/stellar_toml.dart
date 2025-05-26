// Copyright 2023 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/asset/asset_id.dart';
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';

/// [Stellar info file](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md)
/// (also known as TOML file).
class TomlInfo {
  String? version;
  String? networkPassphrase;
  String? federationServer;
  String? authServer;
  String? transferServer;
  String? transferServerSep24;
  String? kycServer;
  String? webAuthEndpoint;
  String? signingKey;
  String? horizonUrl;
  List<String>? accounts;
  String? uriRequestSigningKey;
  String? directPaymentServer;
  String? anchorQuoteServer;
  InfoDocumentation? documentation;

  List<InfoContact>? principals;
  List<InfoCurrency>? currencies;
  List<InfoValidator>? validators;

  TomlInfo();

  bool get hasAuth => webAuthEndpoint != null && signingKey != null;

  static TomlInfo from(flutter_sdk.StellarToml stellarToml) {
    TomlInfo result = TomlInfo();

    result.version = stellarToml.generalInformation.version;
    result.networkPassphrase = stellarToml.generalInformation.networkPassphrase;
    result.federationServer = stellarToml.generalInformation.federationServer;
    result.authServer = stellarToml.generalInformation.authServer;
    result.transferServer = stellarToml.generalInformation.transferServer;
    result.transferServerSep24 =
        stellarToml.generalInformation.transferServerSep24;
    result.kycServer = stellarToml.generalInformation.kYCServer;
    result.webAuthEndpoint = stellarToml.generalInformation.webAuthEndpoint;
    result.signingKey = stellarToml.generalInformation.signingKey;
    result.horizonUrl = stellarToml.generalInformation.horizonUrl;
    result.accounts = stellarToml.generalInformation.accounts;
    result.uriRequestSigningKey =
        stellarToml.generalInformation.uriRequestSigningKey;
    result.directPaymentServer =
        stellarToml.generalInformation.directPaymentServer;
    result.anchorQuoteServer = stellarToml.generalInformation.anchorQuoteServer;

    if (stellarToml.documentation != null) {
      result.documentation = InfoDocumentation.from(stellarToml.documentation!);
    }

    if (stellarToml.pointsOfContact != null) {
      result.principals = List<InfoContact>.empty(growable: true);
      for (var pointOfContact in stellarToml.pointsOfContact!) {
        result.principals!.add(InfoContact.from(pointOfContact));
      }
    }

    if (stellarToml.currencies != null) {
      result.currencies = List<InfoCurrency>.empty(growable: true);
      for (var currency in stellarToml.currencies!) {
        result.currencies!.add(InfoCurrency.from(currency));
      }
    }

    if (stellarToml.validators != null) {
      result.validators = List<InfoValidator>.empty(growable: true);
      for (var validator in stellarToml.validators!) {
        result.validators!.add(InfoValidator.from(validator));
      }
    }
    return result;
  }

  InfoServices get services {
    InfoServices result = InfoServices();
    if (transferServer != null) {
      result.sep6 = Sep6InfoData(transferServer!, anchorQuoteServer: anchorQuoteServer);
    }

    if (hasAuth) {
      result.sep10 = Sep10InfoData(webAuthEndpoint!, signingKey!);
    }

    if (kycServer != null) {
      result.sep12 = Sep12InfoData(kycServer!, signingKey: signingKey);
    }

    if (transferServerSep24 != null) {
      result.sep24 = Sep24InfoData(transferServerSep24!, hasAuth);
    }

    if (directPaymentServer != null) {
      result.sep31 = Sep31InfoData(directPaymentServer!, hasAuth,
          kycServer: kycServer, anchorQuoteServer: anchorQuoteServer);
    }

    return result;
  }
}

class InfoDocumentation {
  String? orgName;
  String? orgDba;
  String? orgUrl;
  String? orgLogo;
  String? orgDescription;
  String? orgPhysicalAddress;
  String? orgPhysicalAddressAttestation;
  String? orgPhoneNumber;
  String? orgPhoneNumberAttestation;
  String? orgKeybase;
  String? orgTwitter;
  String? orgGithub;
  String? orgOfficialEmail;
  String? orgSupportEmail;
  String? orgLicensingAuthority;
  String? orgLicenseType;
  String? orgLicenseNumber;

  static InfoDocumentation from(flutter_sdk.Documentation documentation) {
    InfoDocumentation result = InfoDocumentation();
    result.orgName = documentation.orgName;
    result.orgDba = documentation.orgDBA;
    result.orgUrl = documentation.orgUrl;
    result.orgLogo = documentation.orgLogo;
    result.orgDescription = documentation.orgDescription;
    result.orgPhysicalAddress = documentation.orgPhysicalAddress;
    result.orgPhysicalAddressAttestation =
        documentation.orgPhysicalAddressAttestation;
    result.orgPhoneNumber = documentation.orgPhoneNumber;
    result.orgPhoneNumberAttestation = documentation.orgPhoneNumberAttestation;
    result.orgKeybase = documentation.orgKeybase;
    result.orgTwitter = documentation.orgTwitter;
    result.orgGithub = documentation.orgGithub;
    result.orgOfficialEmail = documentation.orgOfficialEmail;
    result.orgSupportEmail = documentation.orgSupportEmail;
    result.orgLicensingAuthority = documentation.orgLicensingAuthority;
    result.orgLicenseType = documentation.orgLicenseType;
    result.orgLicenseNumber = documentation.orgLicenseNumber;

    return result;
  }
}

class InfoContact {
  String? name;
  String? email;
  String? keybase;
  String? telegram;
  String? twitter;
  String? github;
  String? idPhotoHash;
  String? verificationPhotoHash;

  static InfoContact from(flutter_sdk.PointOfContact pointOfContact) {
    InfoContact result = InfoContact();
    result.name = pointOfContact.name;
    result.email = pointOfContact.email;
    result.keybase = pointOfContact.keybase;
    result.telegram = pointOfContact.telegram;
    result.twitter = pointOfContact.twitter;
    result.github = pointOfContact.github;
    result.idPhotoHash = pointOfContact.idPhotoHash;
    result.verificationPhotoHash = pointOfContact.verificationPhotoHash;
    return result;
  }
}

class InfoValidator {
  String? alias;
  String? displayName;
  String? publicKey;
  String? host;
  String? history;

  static InfoValidator from(flutter_sdk.Validator validator) {
    InfoValidator result = InfoValidator();
    result.alias = validator.alias;
    result.displayName = validator.displayName;
    result.publicKey = validator.publicKey;
    result.host = validator.host;
    result.history = validator.history;
    return result;
  }
}

class InfoCurrency {
  String? code;
  String? issuer;
  String? codeTemplate;
  String? status;
  int? displayDecimals;
  String? name;
  String? desc;
  String? conditions;
  String? image;
  int? fixedNumber;
  int? maxNumber;
  bool? isUnlimited;
  bool? isAssetAnchored;
  String? anchorAssetType;
  String? anchorAsset;
  String? attestationOfReserve;
  String? redemptionInstructions;
  List<String>? collateralAddresses;
  List<String>? collateralAddressMessages;
  List<String>? collateralAddressSignatures;
  bool? regulated;
  String? approvalServer;
  String? approvalCriteria;

  StellarAssetId get assetId {
    if (code != null && code == "native" && issuer == null) {
      return NativeAssetId();
    } else if (code != null && code != "native" && issuer != null) {
      return IssuedAssetId(code: code!, issuer: issuer!);
    } else {
      throw ValidationException("Invalid asset code and issuer pair: $code, $issuer");
    }
  }

  static from(flutter_sdk.Currency currency) {
    InfoCurrency result = InfoCurrency();
    result.code = currency.code;
    result.issuer = currency.issuer;
    result.codeTemplate = currency.codeTemplate;
    result.status = currency.status;
    result.displayDecimals = currency.displayDecimals;
    result.name = currency.name;
    result.desc = currency.desc;
    result.conditions = currency.conditions;
    result.image = currency.image;
    result.fixedNumber = currency.fixedNumber;
    result.maxNumber = currency.maxNumber;
    result.isUnlimited = currency.isUnlimited;

    result.isAssetAnchored = currency.isAssetAnchored;
    result.anchorAssetType = currency.anchorAssetType;
    result.anchorAsset = currency.anchorAsset;
    result.attestationOfReserve = currency.attestationOfReserve;
    result.redemptionInstructions = currency.redemptionInstructions;
    result.collateralAddresses = currency.collateralAddresses;
    result.collateralAddressMessages = currency.collateralAddressMessages;
    result.collateralAddressSignatures = currency.collateralAddressSignatures;
    result.regulated = currency.regulated;
    result.approvalServer = currency.approvalServer;
    result.approvalCriteria = currency.approvalCriteria;
    return result;
  }
}

class InfoServices {
  Sep6InfoData? sep6;
  Sep10InfoData? sep10;
  Sep12InfoData? sep12;
  Sep24InfoData? sep24;
  Sep31InfoData? sep31;
}

/// [SEP-6](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md): Deposit
/// and withdrawal API.
class Sep6InfoData {
  String transferServer;
  String? anchorQuoteServer;

  Sep6InfoData(this.transferServer, {this.anchorQuoteServer});
}

/// [SEP-10](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md): Stellar
/// web authentication.
class Sep10InfoData {
  String webAuthEndpoint;
  String signingKey;

  Sep10InfoData(this.webAuthEndpoint, this.signingKey);
}

/// [SEP-12](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md): Stellar
/// KYC endpoint.
class Sep12InfoData {
  String kycServer;
  String? signingKey;

  Sep12InfoData(this.kycServer, {this.signingKey});
}

/// [SEP-24](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md):
/// Hosted/interactive deposit and withdrawal.
class Sep24InfoData {
  String transferServerSep24;
  bool hasAuth;

  Sep24InfoData(this.transferServerSep24, this.hasAuth);
}

/// [SEP-31](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0031.md):
/// Cross-border payments API.
class Sep31InfoData {
  String directPaymentServer;
  bool hasAuth;
  String? kycServer;
  String? anchorQuoteServer;

  Sep31InfoData(this.directPaymentServer, this.hasAuth,
      {this.kycServer, this.anchorQuoteServer});
}
