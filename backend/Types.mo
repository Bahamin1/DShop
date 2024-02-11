import Nat64 "mo:base/Nat64";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";

module {
  public type ProductMap = HashMap.HashMap<Nat64, Product>;

  public type Product = {
    product_id : Nat64;
    name : Text;
    quantity : Nat64;
    price : Nat64;
    createdAt : Int;
  };

  public type NewProduct = {
    name : Text;
    quantity : Nat64;
    price : Nat64;
  };

  public type CartMap = HashMap.HashMap<Principal, Cart>;

  public type Cart = {
    products : HashMap.HashMap<Nat64, CartProduct>;
    createdAt : Int;
  };

  public type CartProduct = {
    quantity : Nat64;
    product_id : Nat64;
    createdAt : Int;
  };

  public type Receipt = {
    txId : Nat64;
    amount : Nat64;
    createdAt : Int;
    buyer : Principal;
    address : Text;
    txHash : Text;
  };

  public type ReceiptMap = HashMap.HashMap<Nat64, Receipt>;

};
