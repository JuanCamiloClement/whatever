defmodule PhoenixEventStoreDemo.ShoppingCartTest do
  use ExUnit.Case
  use Spear.Client
  alias PhoenixEventStoreDemo.EventStoreDbClient
  alias PhoenixEventStoreDemo.ShoppingCart
  doctest ShoppingCart

  setup do
    event_1 = Spear.Event.new("CartEmptied", [])
    EventStoreDbClient.append([event_1], "TestCart")
    event_2 = Spear.Event.new("CouponRemoved", %{"coupon" => 20})
    EventStoreDbClient.append([event_2], "TestCart")
    stream = EventStoreDbClient.stream!("TestCart")
    {:ok, stream: stream}
  end

  test "Should create cart if cart is empty map" do
    assert %{
             body: %{
               "items" => [],
               "coupon" => nil
             }
           } = ShoppingCart.create(%{})
  end

  test "Should return nil if cart is already created" do
    assert ShoppingCart.create(%{
             "items" => [],
             "coupon" => nil
           }) == nil
  end

  test "Should create ItemAdded event when item name is not in cart" do
    assert %{type: "ItemAdded"} =
             ShoppingCart.add_item(
               %{
                 "items" => [],
                 "coupon" => nil
               },
               %{
                 "name" => "Computer",
                 "price" => 1000,
                 "amount" => 1
               }
             )
  end

  test "Should create ItemQuantityIncreased event when item name is already in cart" do
    assert %{type: "ItemQuantityIncreased"} =
             ShoppingCart.add_item(
               %{
                 "items" => [
                   %{
                     "name" => "Computer",
                     "price" => 1000,
                     "amount" => 1
                   }
                 ],
                 "coupon" => nil
               },
               %{
                 "name" => "Computer",
                 "price" => 1000,
                 "amount" => 1
               }
             )
  end

  test "Should increase item amount by 1 if item is already in cart" do
    %{body: body} =
      ShoppingCart.add_item(
        %{
          "items" => [
            %{
              "name" => "Computer",
              "price" => 1000,
              "amount" => 1
            }
          ],
          "coupon" => nil
        },
        %{
          "name" => "Computer",
          "price" => 1000,
          "amount" => 1
        }
      )

    assert body["newAmount"] == 2
  end

  test "Should create ItemRemoved event if item amount is changed to 0" do
    assert %{type: "ItemRemoved"} =
             ShoppingCart.update_item_quantity(
               %{
                 "items" => [
                   %{
                     "name" => "Computer",
                     "price" => 1000,
                     "amount" => 1
                   }
                 ],
                 "coupon" => nil
               },
               %{
                 "name" => "Computer",
                 "amount" => 0
               }
             )
  end

  test "Should create ItemQuantityIncreased event if new amount is higher than previous amount" do
    assert %{type: "ItemQuantityIncreased"} =
             ShoppingCart.update_item_quantity(
               %{
                 "items" => [
                   %{
                     "name" => "Computer",
                     "price" => 1000,
                     "amount" => 1
                   }
                 ],
                 "coupon" => nil
               },
               %{
                 "name" => "Computer",
                 "amount" => 2
               }
             )
  end

  test "Should create ItemQuantityDecreased event if new amount is higher than previous amount" do
    assert %{type: "ItemQuantityDecreased"} =
             ShoppingCart.update_item_quantity(
               %{
                 "items" => [
                   %{
                     "name" => "Computer",
                     "price" => 1000,
                     "amount" => 2
                   }
                 ],
                 "coupon" => nil
               },
               %{
                 "name" => "Computer",
                 "amount" => 1
               }
             )
  end

  test "Should return nil if new amount is equal to previous amount" do
    assert ShoppingCart.update_item_quantity(
             %{
               "items" => [
                 %{
                   "name" => "Computer",
                   "price" => 1000,
                   "amount" => 1
                 }
               ],
               "coupon" => nil
             },
             %{
               "name" => "Computer",
               "amount" => 1
             }
           ) == nil
  end

  test "Should create ItemRemoved event if item is in list" do
    assert %{type: "ItemRemoved"} =
             ShoppingCart.remove_item(
               %{
                 "items" => [
                   %{
                     "name" => "Computer",
                     "price" => 1000,
                     "amount" => 2
                   }
                 ],
                 "coupon" => nil
               },
               "Computer"
             )
  end

  test "Should return nil if item is not in list" do
    assert ShoppingCart.remove_item(
             %{
               "items" => [],
               "coupon" => nil
             },
             "Computer"
           ) == nil
  end

  test "Should return CartEmptied event if the cart contains items" do
    assert %{type: "CartEmptied"} =
             ShoppingCart.empty_cart(%{
               "items" => [
                 %{
                   "name" => "Computer",
                   "price" => 1000,
                   "amount" => 2
                 }
               ],
               "coupon" => nil
             })
  end

  test "Should return nil if cart items is an empty list" do
    assert ShoppingCart.empty_cart(%{
             "items" => [],
             "coupon" => nil
           }) == nil
  end

  test "Should create CouponAdded event if cart coupon is nil" do
    assert %{type: "CouponAdded"} =
             ShoppingCart.add_discount_coupon(
               %{
                 "items" => [],
                 "coupon" => nil
               },
               20
             )
  end

  test "Should return nil if cart already has coupon" do
    assert ShoppingCart.add_discount_coupon(
             %{
               "items" => [],
               "coupon" => %{"percentage" => 20}
             },
             10
           ) == nil
  end

  test "Should create CouponRemoved event if cart has coupon" do
    assert %{type: "CouponRemoved"} =
             ShoppingCart.remove_discount_coupon(%{
               "items" => [],
               "coupon" => %{"percentage" => 20}
             })
  end

  test "Should return nil if cart has no coupon" do
    assert ShoppingCart.remove_discount_coupon(%{
             "items" => [],
             "coupon" => nil
           }) == nil
  end

  test "Should return cart with key items as empty list and coupon as nil" do
    event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([event], "TestCart")
    stream = EventStoreDbClient.stream!("TestCart")

    current_cart = ShoppingCart.build_cart_from_stream(stream)

    assert current_cart["items"] == []
    assert current_cart["coupon"] == nil
  end

  test "Should add item to cart items key" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([event], "TestCart")
    stream = EventStoreDbClient.stream!("TestCart")

    current_cart = ShoppingCart.build_cart_from_stream(stream)

    assert current_cart["items"] == [
             %{
               "name" => "Computer",
               "price" => 1000,
               "amount" => 1
             }
           ]
  end

  test "Should increase item amount" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event], "TestCart")

    event =
      Spear.Event.new("ItemQuantityIncreased", %{
        "name" => "Computer",
        "previousAmount" => 1,
        "newAmount" => 2
      })

    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    current_cart = ShoppingCart.build_cart_from_stream(stream)

    assert current_cart["items"] == [
             %{
               "name" => "Computer",
               "price" => 1000,
               "amount" => 2
             }
           ]
  end

  test "Should decrease item amount" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 2
      })

    EventStoreDbClient.append([add_item_event], "TestCart")

    event =
      Spear.Event.new("ItemQuantityDecreased", %{
        "name" => "Computer",
        "previousAmount" => 2,
        "newAmount" => 1
      })

    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    current_cart = ShoppingCart.build_cart_from_stream(stream)

    assert current_cart["items"] == [
             %{
               "name" => "Computer",
               "price" => 1000,
               "amount" => 1
             }
           ]
  end

  test "Should remove item" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event], "TestCart")

    event =
      Spear.Event.new("ItemRemoved", %{
        "name" => "Computer"
      })

    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    current_cart = ShoppingCart.build_cart_from_stream(stream)

    assert current_cart["items"] == []
  end

  test "Should empty cart" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event_1 =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event_1], "TestCart")

    add_item_event_2 =
      Spear.Event.new("ItemAdded", %{
        "name" => "Cellphone",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event_2], "TestCart")

    event = Spear.Event.new("CartEmptied", [])
    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    current_cart = ShoppingCart.build_cart_from_stream(stream)

    assert current_cart["items"] == []
  end

  test "Should add discount coupon" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    event = Spear.Event.new("CouponAdded", %{"percentage" => 20})
    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")
    current_cart = ShoppingCart.build_cart_from_stream(stream)

    assert current_cart["coupon"] == %{"percentage" => 20}
  end

  test "Should remove discount coupon" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    event = Spear.Event.new("CouponRemoved", %{"coupon" => 20})
    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")
    current_cart = ShoppingCart.build_cart_from_stream(stream)

    assert current_cart["coupon"] == nil
  end

  test "Should return cart total 0 after only creating the cart" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    cart_total = ShoppingCart.calculate_cart_total(stream)

    assert cart_total == 0
  end

  test "Should return cart total 1000 after adding a computer to the items" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    cart_total = ShoppingCart.calculate_cart_total(stream)

    assert cart_total == 1000
  end

  test "Should return cart total 2000 after increasing item quantity by 1" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event], "TestCart")

    event =
      Spear.Event.new("ItemQuantityIncreased", %{
        "name" => "Computer",
        "previousAmount" => 1,
        "newAmount" => 2
      })

    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    cart_total = ShoppingCart.calculate_cart_total(stream)

    assert cart_total == 2000
  end

  test "Should return cart total 1000 after decreasing item quantity from 2 to 1" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 2
      })

    EventStoreDbClient.append([add_item_event], "TestCart")

    event =
      Spear.Event.new("ItemQuantityDecreased", %{
        "name" => "Computer",
        "previousAmount" => 2,
        "newAmount" => 1
      })

    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    cart_total = ShoppingCart.calculate_cart_total(stream)

    assert cart_total == 1000
  end

  test "Should return cart total 0 after removing item in list" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event], "TestCart")

    event =
      Spear.Event.new("ItemRemoved", %{
        "name" => "Computer"
      })

    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    cart_total = ShoppingCart.calculate_cart_total(stream)

    assert cart_total == 0
  end

  test "Should return cart total 0 after emptying cart" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event_1 =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event_1], "TestCart")

    add_item_event_2 =
      Spear.Event.new("ItemAdded", %{
        "name" => "Cellphone",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event_2], "TestCart")

    event = Spear.Event.new("CartEmptied", [])
    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    cart_total = ShoppingCart.calculate_cart_total(stream)

    assert cart_total == 0
  end

  test "Should return cart total 800 after adding coupon of 20%" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event], "TestCart")

    event = Spear.Event.new("CouponAdded", %{"percentage" => 20})
    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    cart_total = ShoppingCart.calculate_cart_total(stream)

    assert cart_total == 800
  end

  test "Should return cart total 1000 after removing discount coupon" do
    create_cart_event = Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    EventStoreDbClient.append([create_cart_event], "TestCart")

    add_item_event =
      Spear.Event.new("ItemAdded", %{
        "name" => "Computer",
        "price" => 1000,
        "amount" => 1
      })

    EventStoreDbClient.append([add_item_event], "TestCart")

    add_coupon_event = Spear.Event.new("CouponAdded", %{"percentage" => 20})
    EventStoreDbClient.append([add_coupon_event], "TestCart")

    event = Spear.Event.new("CouponRemoved", %{"coupon" => 20})
    EventStoreDbClient.append([event], "TestCart")

    stream = EventStoreDbClient.stream!("TestCart")

    cart_total = ShoppingCart.calculate_cart_total(stream)

    assert cart_total == 1000
  end
end
