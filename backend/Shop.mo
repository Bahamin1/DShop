import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import { range; toArray } "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Map "mo:map/Map";
import { nhash; phash } "mo:map/Map";

import ckEth "ckEth";
import ckEthMinter "ckEthMinter";
import E "EthUtils";
import EthUtils "EthUtils";
import EvmRpc "EvmRpc";
import T "Types";

shared ({ caller }) actor class Shop() = this {

  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\
  ////////////Change and call Owner\\\\\\\\\\\\\
  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\\\

  stable var owner : Principal = caller;

  public shared func getOwner() : async Principal {
    return owner;
  };

  public shared ({ caller }) func setOwner(newOwner : Principal) : async Result.Result<Principal, Text> {
    if (caller != owner) {
      return #err("Only owner can change owner !");
    };
    owner := newOwner;
    return #ok(owner);
  };

  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\
  ////////////////////Product\\\\\\\\\\\\\\\\\\\
  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\\\
  stable let productMap = Map.new<Nat, T.Product>();
  private stable var next_product_id : Nat = 0;

  func products() : [T.Product] {
    return Iter.toArray(Map.vals<Nat, T.Product>(productMap));
  };

  func productGet(productId : Nat) : ?T.Product {
    return Map.get(productMap, nhash, productId);
  };

  func productPut(productId : Nat, product : T.Product) : () {
    return Map.set(productMap, nhash, productId, product);
  };

  func productRemoveQuantity(productId : Nat, quantity : Nat) : () {
    let product = productGet(productId);

    switch (product) {
      case (null) {
        return;
      };
      case (?product) {
        let newProduct : T.Product = {
          product_id = productId;
          name = product.name;
          quantity = product.quantity - quantity;
          price = product.price;
          createdAt = product.createdAt;
        };
        productPut(productId, newProduct);
      };
    };
  };

  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\
  /////////////////////Cart\\\\\\\\\\\\\\\\\\\\\////////////////////////////Must be some Work on it\\\\\\\\\\\\\\\\\\
  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\\\

  func productsCart() : [T.CartProduct] {
    return Iter.toArray(productCartMap.vals());
  };
  stable var productCartMapEntries : [(Nat, T.CartProduct)] = [];
  let productCartMap : T.ProductsCartMap = HashMap.HashMap<Nat, T.CartProduct>(0, Nat.equal, Hash.hash);
  let cartMap : T.CartMap = HashMap.HashMap<Principal, T.Cart>(0, Principal.equal, Principal.hash);

  //////////////Preupgrade and Postupgrade for cart\\\\\\\\\\\\\

  system func preupgrade() {
    productCartMapEntries := Iter.toArray(productCartMap.entries());
  };

  system func postupgrade() {
    for ((n, cart) in productCartMapEntries.vals()) {
      productCartMap.put(n, cart);
    };
  };

  func cart_get(buyer : Principal) : ?T.Cart {
    return cartMap.get(buyer);
  };

  func cart_put(buyer : Principal, cart : T.Cart) : () {
    cartMap.put(buyer, cart);
  };

  func cart_get_products(buyer : Principal) : Iter.Iter<T.CartProduct> {
    let cart = cart_get(buyer);

    switch (cart) {
      case (null) {
        return Buffer.Buffer<T.CartProduct>(0).vals();
      };
      case (?cart) {
        return cart.products.vals();
      };
    };
  };

  func cart_add_product(buyer : Principal, product_id : Nat, quantity : Nat) : () {
    let cart = cart_get(buyer);

    switch (cart) {
      case (null) {
        return;
      };
      case (?cart) {
        let cartProduct : T.CartProduct = {
          product_id = product_id;
          quantity = quantity;
          createdAt = Time.now();
        };

        cart.products.put(product_id, cartProduct);

        cart_put(buyer, cart);
      };
    };
  };
  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\
  ////////////////////Reciept\\\\\\\\\\\\\\\\\\\\\\
  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\
  stable let recieptMap = Map.new<Nat, T.Receipt>();
  private stable var next_reciept_id : Nat = 0;

  func recieptGet(txId : Nat) : ?T.Receipt {
    return Map.get(recieptMap, nhash, txId);
  };

  func recieptPut(txId : Nat, reciept : T.Receipt) : () {
    return Map.set(recieptMap, nhash, txId, reciept);
  };

  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\
  /////////////Processed Transaction\\\\\\\\\\\\\\\
  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\
  let processedTransactions : Buffer.Buffer<Text> = Buffer.Buffer<Text>(0);

  func processed_transaction_exists(txHash : Text) : Bool {
    for (tx in processedTransactions.vals()) {
      if (tx == txHash) {
        return true;
      };
    };

    return false;
  };

  func processed_transaction_put(txHash : Text) : () {
    processedTransactions.add(txHash);
  };

  ///////Get the canister id as bytes\\\\\\\
  public shared func canisterDepositPrincipal() : async Text {
    let account = Principal.fromActor(this);

    let id = E.principalToBytes32(account);

    return Text.toLowercase(id);
  };

  /////////////Get all products\\\\\\\\\\\\\\\
  public shared func getProducts() : async [T.Product] {
    return products();
  };

  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\
  ////////////////Owner Functions\\\\\\\\\\\\\\\
  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\\\

  public shared ({ caller }) func addProduct(product : T.NewProduct) : async Result.Result<Nat, Text> {
    if (caller != owner) {
      return #err("Only owner can create product");
    };

    let newProduct : T.Product = {
      product_id = next_product_id;
      name = product.name;
      quantity = product.quantity;
      price = product.price;
      createdAt = Time.now();
    };
    productPut(next_product_id, newProduct);

    next_product_id += 1;

    return #ok(next_product_id -1);
  };

  // Update an product

  public shared ({ caller }) func updateProduct(product_id : Nat, updateProduct : T.NewProduct) : async Result.Result<Nat, Text> {
    if (caller != owner) {
      return #err("Only owner can update product");
    };

    let product = productGet(product_id);
    switch (product) {
      case (null) {
        return #err("Product not found");
      };
      case (?product) {
        let newProduct : T.Product = {
          product_id = product_id;
          name = updateProduct.name;
          quantity = updateProduct.quantity;
          price = updateProduct.price;
          createdAt = product.createdAt;
        };

        productPut(product_id, newProduct);

        return #ok(product_id);
      };
    };
  };

  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\
  ////////////////Users Functions\\\\\\\\\\\\\\\
  ///////////////////////\\\\\\\\\\\\\\\\\\\\\\\\

  public shared ({ caller }) func getCartProducts() : async [T.CartProduct] {
    return Iter.toArray(cart_get_products(caller));
  };

  // Cart an product
  public shared ({ caller }) func addToCart(product_id : Nat, quantity : Nat) : async Result.Result<Nat, Text> {
    let product = productGet(product_id);

    switch (product) {
      case (null) {
        return #err("Product not found");
      };
      case (?product) {
        if (product.quantity < quantity) {
          return #err("Not enough quantity");
        };

        let currentCart = cart_get(caller);

        switch (currentCart) {
          case (null) {
            let cart : T.Cart = {
              products = HashMap.HashMap<Nat, T.CartProduct>(1, Nat.equal, Hash.hash);
              createdAt = Time.now();
            };

            cart_put(caller, cart);

            cart_add_product(caller, product_id, quantity);
            productRemoveQuantity(product_id, quantity);

            return #ok(product_id);
          };
          case (?cart) {
            cart_add_product(caller, product_id, quantity);
            productRemoveQuantity(product_id, quantity);

            return #ok(product_id);
          };
        };
      };
    };
  };

  ////////////////Check Out\\\\\\\\\\\\\\\
  public shared ({ caller }) func checkout() : async Result.Result<Nat, Text> {
    let cart = cart_get(caller);

    switch (cart) {
      case (null) {
        return #err("No cart found");
      };
      case (?cart) {
        var total : Nat = 0;

        for (cart_product in cart.products.vals()) {
          let product = productGet(cart_product.product_id);
          switch (product) {
            case (null) {
              return #err("Product not found");
            };
            case (?product) {
              total += product.price * cart_product.quantity;
            };
          };
        };

        return #ok(total);
      };
    };
  };

  //////////////Get latest block\\\\\\\\\\\\\\\

  public shared func getLatestBlock() : async EvmRpc.Block {
    return await EvmRpc.getLatestEthereumBlock();
  };

  // Get reciept receipt
  public shared func getTransactionReceipt(txHash : Text) : async ?EvmRpc.TransactionReceipt {
    return await EvmRpc.getTransactionReceipt(txHash);
  };

  // Verify reciept
  private stable var next_receipt_id : Nat = 0;
  public shared ({ caller }) func verifyTransaction(txHash : Text) : async Result.Result<(Nat, Text, Nat, Nat), Text> {
    let cart = cart_get(caller);

    if (processed_transaction_exists(txHash)) {
      return #err("Transaction already processed");
    };

    let receipt = await getTransactionReceipt(txHash);

    processed_transaction_put(txHash);

    switch (receipt) {
      case (null) {
        return #err("Transaction not found");
      };
      case (?receipt) {
        if (receipt.to != EthUtils.MINTER_ADDRESS) {
          Debug.trap("Transaction to wrong address");
        };

        let log = receipt.logs[0];

        if (log.address != EthUtils.MINTER_ADDRESS) {
          Debug.trap("Log from wrong address");
        };

        let principal = await canisterDepositPrincipal();
        let log_principal = Text.toLowercase(log.topics[2]);

        if (log_principal != principal) {
          Debug.trap("Principal does not match");
        };

        let txId = next_receipt_id;
        next_receipt_id += 1;

        let status = receipt.status;
        let amount = EthUtils.hexToNat(log.data);
        let address = EthUtils.hexToEthAddress(log.topics[1]);

        return #ok(status, address, amount, txId);

        let reciept : T.Receipt = {
          txId = txId;
          txHash = txHash;
          address = address;
          buyer = caller;
          amount = amount;
          createdAt = Time.now();
        };

        recieptPut(txId, reciept);

        return #ok(status, address, amount, txId);
      };
    };
  };

  // Pay for the cart
  public shared ({ caller }) func pay(hash : Text) : async Result.Result<Nat, Text> {
    let cart = cart_get(caller);

    switch (cart) {
      case (null) {
        return #err("No cart found");
      };
      case (?cart) {
        var total : Nat = 0;

        for (cart_product in cart.products.vals()) {
          let product = productGet(cart_product.product_id);
          switch (product) {
            case (null) {
              return #err("Product not found");
            };
            case (?product) {
              total += product.price * cart_product.quantity;
            };
          };
        };

        let result = await verifyTransaction(hash);

        switch (result) {
          case (#err(err)) {
            return #err(err);
          };
          case (#ok(status, address, amount, txId)) {
            if (status != 1) {
              return #err("Transaction failed");
            };

            if (amount < total) {
              return #err("Insufficient amount");
            };

            let txId = next_receipt_id;
            next_receipt_id += 1;

            let reciept : T.Receipt = {
              txId = txId;
              txHash = hash;
              address = address;
              buyer = caller;
              amount = amount;
              createdAt = Time.now();
            };

            recieptPut(txId, reciept);

            return #ok(txId);
          };
        };
      };
    };
  };

  // Get reciept
  public func getReceipt(txId : Nat) : async ?T.Receipt {
    return recieptGet(txId);
  };

  // Get all reciept
  public shared func getReceipts() : async [T.Receipt] {
    return Iter.toArray(Map.vals<Nat, T.Receipt>(recieptMap));
  };

  /////////////////////\\\\\\\\\\\\\\\\\\\\\\
  //////////////////CK-ETH\\\\\\\\\\\\\\\\\\\\
  /////////////////////\\\\\\\\\\\\\\\\\\\\\\\\

  // Get the balance of the canister
  public shared func ckEthBalance() : async Nat {
    return await ckEth.balanceOf(Principal.fromActor(this));
  };

  // Transfer ckEth
  public shared ({ caller }) func ckETHtransfer(to : Principal, amount : Nat) : async ckEth.TransferResult {
    if (caller != owner) {
      return Debug.trap("Only owner can transfer ckEth");
    };

    return await ckEth.transfer(to, amount);
  };

  // Approve ckEth
  public shared ({ caller }) func ckETHapprove(spender : Principal, amount : Nat) : async ckEth.ApproveResult {
    if (caller != owner) {
      return Debug.trap("Only owner can approve ckEth");
    };

    return await ckEth.approve(spender, amount);
  };

  // Withdrawal -----------------------------
  public shared ({ caller }) func withdrawEth(amount : Nat, recipient : Text) : async ckEthMinter.RetrieveResult {
    if (caller != owner) {
      return Debug.trap("Only owner can withdraw Eth");
    };

    return await ckEthMinter.withdrawEth(amount, recipient);
  };
};
