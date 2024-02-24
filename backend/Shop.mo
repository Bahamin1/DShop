import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import ckEth "ckEth";
import ckEthMinter "ckEthMinter";
import EthUtils "EthUtils";
import EvmRpc "EvmRpc";
import Hex "Hex";
import Types "Types";

shared ({ caller }) actor class Shop() = this {
  stable var owner : Principal = caller;

  public shared func getcaller() : async Principal {
    return caller;
  };

  public shared ({ caller }) func setOwner(newOwner : Principal) : async Result.Result<Principal, Text> {
    if (caller != owner) {
      return #err("Only owner can set owner");
    };

    owner := newOwner;
    return #ok(owner);
  };

  // Product -------------------------------------------------------
  let product_map : Types.ProductMap = HashMap.HashMap<Nat64, Types.Product>(0, Nat64.equal, Nat64.toNat32);
  private stable var next_product_id : Nat64 = 0;

  func products() : [Types.Product] {
    return Iter.toArray(product_map.vals());
  };

  func product_get(product_id : Nat64) : ?Types.Product {
    return product_map.get(product_id);
  };

  func product_put(product_id : Nat64, product : Types.Product) : () {
    product_map.put(product_id, product);
  };

  func product_remove_quantity(product_id : Nat64, quantity : Nat64) : () {
    let product = product_get(product_id);

    switch (product) {
      case (null) {
        return;
      };
      case (?product) {
        let newProduct : Types.Product = {
          product_id = product_id;
          name = product.name;
          quantity = product.quantity - quantity;
          price = product.price;
          createdAt = product.createdAt;
        };

        product_put(product_id, newProduct);
      };
    };
  };
  // --------------------------------------------------------------
  //
  //
  // Cart ---------------------------------------------------------
  let cart_map : Types.CartMap = HashMap.HashMap<Principal, Types.Cart>(0, Principal.equal, Principal.hash);

  func cart_get(buyer : Principal) : ?Types.Cart {
    return cart_map.get(buyer);
  };

  func cart_put(buyer : Principal, cart : Types.Cart) : () {
    cart_map.put(buyer, cart);
  };

  func cart_get_products(buyer : Principal) : Iter.Iter<Types.CartProduct> {
    let cart = cart_get(buyer);

    switch (cart) {
      case (null) {
        return Buffer.Buffer<Types.CartProduct>(0).vals();
      };
      case (?cart) {
        return cart.products.vals();
      };
    };
  };

  func cart_add_product(buyer : Principal, product_id : Nat64, quantity : Nat64) : () {
    let cart = cart_get(buyer);

    switch (cart) {
      case (null) {
        return;
      };
      case (?cart) {
        let cartProduct : Types.CartProduct = {
          product_id = product_id;
          quantity = quantity;
          createdAt = Time.now();
        };

        cart.products.put(product_id, cartProduct);

        cart_put(buyer, cart);
      };
    };
  };
  // ----------------------------------------------------------------------
  //
  //
  // Receipt --------------------------------------------------------------
  let receipt_map : Types.ReceiptMap = HashMap.HashMap<Nat64, Types.Receipt>(0, Nat64.equal, Nat64.toNat32);
  private stable var next_receipt_id : Nat64 = 0;

  func reciept_get(txId : Nat64) : ?Types.Receipt {
    return receipt_map.get(txId);
  };

  func receipt_put(txId : Nat64, reciept : Types.Receipt) : () {
    receipt_map.put(txId, reciept);
  };
  // ----------------------------------------------------------------------
  //
  //
  // ProcessedTransaction -------------------------------------------------
  let processed_transactions : Buffer.Buffer<Text> = Buffer.Buffer<Text>(0);

  func processed_transaction_exists(txHash : Text) : Bool {
    for (tx in processed_transactions.vals()) {
      if (tx == txHash) {
        return true;
      };
    };

    return false;
  };

  func processed_transaction_put(txHash : Text) : () {
    processed_transactions.add(txHash);
  };
  // ----------------------------------------------------------------------

  // Get the canister id as bytes
  public shared func canisterDepositPrincipal() : async Text {
    let account = Principal.fromActor(this);

    let id = EthUtils.principalToBytes32(account);

    return Text.toUppercase(id);
  };

  // Get all products
  public shared func getProducts() : async [Types.Product] {
    return products();
  };

  // Create a new product
  public shared ({ caller }) func addProduct(product : Types.NewProduct) : async Result.Result<Nat64, Text> {
    if (caller != owner) {
      return #err("Only owner can create product");
    };

    let newProduct : Types.Product = {
      product_id = next_product_id;
      name = product.name;
      quantity = product.quantity;
      price = product.price;
      createdAt = Time.now();
    };
    product_put(next_product_id, newProduct);

    next_product_id += 1;

    return #ok(next_product_id -1);
  };

  // Update an product

  public shared ({ caller }) func updateProduct(product_id : Nat64, updateProduct : Types.NewProduct) : async Result.Result<Nat64, Text> {
    if (caller != owner) {
      return #err("Only owner can update product");
    };

    let product = product_get(product_id);
    switch (product) {
      case (null) {
        return #err("Product not found");
      };
      case (?product) {
        let newProduct : Types.Product = {
          product_id = product_id;
          name = updateProduct.name;
          quantity = updateProduct.quantity;
          price = updateProduct.price;
          createdAt = product.createdAt;
        };

        product_put(product_id, newProduct);

        return #ok(product_id);
      };
    };
  };

  // Get all product
  public shared ({ caller }) func getCartProducts() : async [Types.CartProduct] {
    return Iter.toArray(cart_get_products(caller));
  };

  // Cart an product
  public shared ({ caller }) func addToCart(product_id : Nat64, quantity : Nat64) : async Result.Result<Nat64, Text> {
    let product = product_get(product_id);

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
            let cart : Types.Cart = {
              products = HashMap.HashMap<Nat64, Types.CartProduct>(0, Nat64.equal, Nat64.toNat32);
              createdAt = Time.now();
            };

            cart_put(caller, cart);

            cart_add_product(caller, product_id, quantity);
            product_remove_quantity(product_id, quantity);

            return #ok(product_id);
          };
          case (?cart) {
            cart_add_product(caller, product_id, quantity);
            product_remove_quantity(product_id, quantity);

            return #ok(product_id);
          };
        };
      };
    };
  };

  // Checkout
  public shared ({ caller }) func checkout() : async Result.Result<Nat64, Text> {
    let cart = cart_get(caller);

    switch (cart) {
      case (null) {
        return #err("No cart found");
      };
      case (?cart) {
        var total : Nat64 = 0;

        for (cart_product in cart.products.vals()) {
          let product = product_get(cart_product.product_id);
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

  // Get latest block
  public shared func getLatestBlock() : async EvmRpc.Block {
    return await EvmRpc.getLatestEthereumBlock();
  };

  // Get reciept receipt
  public shared func getTransactionReceipt(txHash : Text) : async ?EvmRpc.TransactionReceipt {
    return await EvmRpc.getTransactionReceipt(txHash);
  };

  // Verify reciept
  public shared func verifyTransaction(txHash : Text) : async Result.Result<(Nat, Text, Nat64), Text> {
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
        let log_principal = Text.toUppercase(log.topics[2]);

        if (log_principal != principal) {
          Debug.trap("Principal does not match");
        };

        let status = receipt.status;
        let amount = EthUtils.hexToNat(log.data);
        let address = EthUtils.hexToEthAddress(log.topics[1]);

        return #ok(status, address, amount);
      };
    };
  };

  // Pay for the cart
  public shared ({ caller }) func pay(hash : Text) : async Result.Result<Nat64, Text> {
    let cart = cart_get(caller);

    switch (cart) {
      case (null) {
        return #err("No cart found");
      };
      case (?cart) {
        var total : Nat64 = 0;

        for (cart_product in cart.products.vals()) {
          let product = product_get(cart_product.product_id);
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
          case (#ok(status, address, amount)) {
            if (status != 1) {
              return #err("Transaction failed");
            };

            if (amount < total) {
              return #err("Insufficient amount");
            };

            let txId = next_receipt_id;
            next_receipt_id += 1;

            let reciept : Types.Receipt = {
              txId = txId;
              txHash = hash;
              address = address;
              buyer = caller;
              amount = amount;
              createdAt = Time.now();
            };

            receipt_put(txId, reciept);

            return #ok(txId);
          };
        };
      };
    };
  };

  // Get reciept
  public func getReceipt(txId : Nat64) : async ?Types.Receipt {
    return reciept_get(txId);
  };

  // Get all reciept
  public shared func getReceipts() : async [Types.Receipt] {
    return Iter.toArray(receipt_map.vals());
  };

  // ---- ckEth ----

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
