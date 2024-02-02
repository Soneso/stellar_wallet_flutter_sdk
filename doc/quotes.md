
# Quotes

The [SEP-38](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md) standard defines a way for anchors to provide quotes for the exchange of an off-chain asset and a different on-chain asset, and vice versa.
Quotes may be [indicative](https://www.investopedia.com/terms/i/indicativequote.asp) or [firm](https://www.investopedia.com/terms/f/firmquote.asp) ones.
When either is used is explained in the sections below.


## Creating Sep-38 Object

Let's start with creating a sep38 object, which we'll use for all SEP-38 interactions.
Authentication is optional for these requests, and depends on the anchor implementation. For our example we will include it.

Authentication is done using [Sep-10](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md), and we add the authentication token to the sep38 object.

```dart
var accountKp = ... // our account keypair

var auth = await anchor.sep10();
var authToken = await auth.authenticate(accountKp);
var sep38 = anchor.sep38(authToken: authToken);
```

## Get Anchor Information

First, let's get information about the anchor's support for [SEP-38](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md). The response gives what stellar on-chain assets and off-chain assets are available for trading.

```dart
var resp = await sep38.info();
```

For example a response will look like this. The asset identifiers are described below in Asset Identification Format.

```dart
List<QuoteInfoAsset> infoAssets = resp.assets;

for (QuoteInfoAsset infoAsset in infoAssets) {
   String asset = infoAsset.asset; 
   // e.g. 'stellar:SRT:GCDNJUBQSX7AJWLJACMJ7I4BC3Z47BQUTMHEICZLE6MU4KQBRYG5JY6B'
   
   List<String>? countryCodes = infoAsset.countryCodes;
   List<QuoteSellDeliveryMethod>? sellDeliveryMethods = infoAsset.sellDeliveryMethods;
   List<QuoteBuyDeliveryMethod>? buyDeliveryMethods = infoAsset.buyDeliveryMethods;
}
```

## Asset Identification Format

Before calling other endpoints we should understand the scheme used to identify assets in this protocol. The following format is used:

`<scheme>:<identifer>`

The currently accepted scheme values are `stellar` for Stellar assets, and `iso4217` for fiat currencies.

For example to identify USDC on Stellar we would use:

`stellar:USDC:GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN`

And to identify fiat USD we would use:

`iso4217:USD`

Further explanation can be found in [SEP-38 specification](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0038.md#asset-identification-format).

## Get Prices

Now let's get [indicative](https://www.investopedia.com/terms/i/indicativequote.asp) prices from the anchor in exchange for a given asset. This is an indicative price. The actual price will be calculated at conversion time once the Anchor receives the funds from a user.

In our example we're getting prices for selling 5 fiat USD.

```dart
var resp = await sep38.prices(sellAsset: "iso4217:USD", sellAmount: "5");
```

The response gives the asset prices for exchanging the requested sell asset. For example, a response look like this:

```dart
List<QuoteBuyAsset> buyAssets = resp.buyAssets;

for (QuoteBuyAsset buyAssetInfo in buyAssets) {
    String asset = buyAssetInfo.asset; 
    // e.g. 'stellar:SRT:GCDNJUBQSX7AJWLJACMJ7I4BC3Z47BQUTMHEICZLE6MU4KQBRYG5JY6B'
    
    String price = buyAssetInfo.price; // e.g. '5.42'
    in decimals = buyAssetInfo.decimals; // e.g. 7
}
```

## Get Prices

Next, let's get an [indicative](https://www.investopedia.com/terms/i/indicativequote.asp) price for a certain pair.

Once again this is an indicative value. The actual price will be calculated at conversion time once the Anchor receives the funds from a User.

Either a `sellAmount` or `buyAmount` value must be given, but not both. And `context` refers to what Stellar SEP context this will be used for (ie. `sep6`, `sep24`, or `sep31`).

```dart
var resp = await sep38.price(
    context: "sep6",
    sellAsset: "iso4217:USD",
    buyAsset: "stellar:SRT:GCDNJUBQSX7AJWLJACMJ7I4BC3Z47BQUTMHEICZLE6MU4KQBRYG5JY6B",
    sellAmount: "5");
```

The response gives information for exchanging these assets. For example, a response will look like this:

```dart
String totalPrice = resp.totalPrice;
String price = resp.price;
String sellAmount = resp.sellAmount;
String buyAmount = resp.buyAmount;
ConversionFee fee = resp.fee;
```

## Post Quote

Now let's get a [firm](https://www.investopedia.com/terms/f/firmquote.asp) quote from the anchor.
As opposed to the earlier endpoints, this quote is stored by the anchor for a certain period of time.
We will show how we can grab the quote again later.

```dart
var resp = await sep38.requestQuote(
    context: "sep6",
    sellAsset: "iso4217:USD",
    buyAsset: "stellar:SRT:GCDNJUBQSX7AJWLJACMJ7I4BC3Z47BQUTMHEICZLE6MU4KQBRYG5JY6B",
    sellAmount: "5");
```
However now the response gives an `id` that we can use to identify the quote. The `expiresAt` field tells us how long the anchor will wait to receive funds for this quote.

An example response looks like this:

```dart
String quoteId = resp.id; // e.g. '019417b3-91ce-473a-929f-15e19470733a'
DateTime expiresAt = resp.expiresAt;
String totalPrice = resp.totalPrice;
String price = resp.price;
String sellAsset = resp.sellAsset;
String sellAmount = resp.sellAmount; 
String buyAsset = resp.buyAsset;
String buyAmount = resp.buyAmount;
ConversionFee fee = resp.fee;
```

Hint: This endpoint requires SEP-10 Auth. If not given in the sep38 constructor, you can pass it as a parameter in the method call.

## Get Quote

Now let's get the previously requested quote. To do that we use the `id` from the `.requestQuote()` response.

```dart
var quoteId = resp.id;
var getResp = await sep38.getQuote(quoteId);
```
The response should match the one given from `.requestQuote()` we made earlier.

Hint: This endpoint requires SEP-10 Auth. If not given in the sep38 constructor, you can pass it as a parameter in the method call.