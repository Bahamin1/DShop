import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

module {
  public type ProductMap = HashMap.HashMap<Nat, Product>;

  public type Product = {
    product_id : Nat;
    name : Text;
    quantity : Nat;
    price : Nat;
    createdAt : Int;
  };

  public type NewProduct = {
    name : Text;
    quantity : Nat;
    price : Nat;
  };

  public type CartMap = HashMap.HashMap<Principal, Cart>;
  public type ProductsCartMap = HashMap.HashMap<Nat, CartProduct>;

  public type Cart = {
    products : HashMap.HashMap<Nat, CartProduct>;
    createdAt : Int;
  };

  public type CartProduct = {
    quantity : Nat;
    product_id : Nat;
    createdAt : Int;
  };

  public type Receipt = {
    txId : Nat;
    amount : Nat;
    createdAt : Int;
    buyer : Principal;
    address : Text;
    txHash : Text;
  };

  public type ReceiptMap = HashMap.HashMap<Nat, Receipt>;

};
