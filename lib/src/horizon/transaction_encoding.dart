// Copyright 2026 The Stellar Wallet Flutter SDK Authors. All rights reserved.
// Use of this source code is governed by a license that can be
// found in the LICENSE file.

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart' as flutter_sdk;
import 'package:stellar_wallet_flutter_sdk/src/exceptions/exceptions.dart';

/// Encodes [transaction] once and throws a [ValidationException] whose
/// message holds the reason of `stellar_flutter_sdk` when the SDK refuses to
/// encode it, such as for a value over its XDR limit.
///
/// `stellar_flutter_sdk` creates a transaction without encoding it, while
/// signing and submitting encode it.
void checkEncodable(flutter_sdk.AbstractTransaction transaction) {
  refusalAsValidation(
    'The transaction cannot be encoded',
    transaction.toEnvelopeXdrBase64,
  );
}

/// Returns the result of [run] and throws a [ValidationException] whose
/// message is [refusal] followed by the reason of `stellar_flutter_sdk` when
/// the SDK refuses to build or convert a transaction in [run].
///
/// The SDK refuses with an [Exception], a [RangeError] or [ArgumentError],
/// which `on Exception catch` does not catch, or an [UnsupportedError], such
/// as for a payment of a liquidity pool share. A [ValidationException] takes
/// only an [Exception] as its cause, so the message keeps the reason. The
/// SDK's text of the error leaves out a value that the SDK masks, such as a
/// secret seed.
T refusalAsValidation<T>(String refusal, T Function() run) {
  try {
    return run();
  } on Exception catch (e) {
    throw ValidationException('$refusal: $e', cause: e);
  } on ArgumentError catch (e) {
    throw ValidationException('$refusal: $e');
  } on UnsupportedError catch (e) {
    throw ValidationException('$refusal: $e');
  }
}
