defmodule PhoenixEventStoreDemo.ShoppingCart do
  use Spear.Client

  def create(current_cart) do
    if current_cart == %{} do
      Spear.Event.new("CartCreated", %{"items" => [], "coupon" => nil})
    else
      nil
    end
  end

  def add_item(current_cart, params) do
    case Enum.find(current_cart["items"], &(&1["name"] == params["name"])) do
      nil ->
        Spear.Event.new("ItemAdded", params)

      item ->
        Spear.Event.new("ItemQuantityIncreased", %{
          "name" => item["name"],
          "previousAmount" => item["amount"],
          "newAmount" => item["amount"] + 1
        })
    end
  end

  def update_item_quantity(current_cart, params) do
    item =
      Enum.find(current_cart["items"], &(&1["name"] == params["name"]))

    cond do
      params["amount"] == 0 ->
        Spear.Event.new("ItemRemoved", %{
          "name" => item["name"]
        })

      item["amount"] < params["amount"] ->
        Spear.Event.new("ItemQuantityIncreased", %{
          "name" => item["name"],
          "previousAmount" => item["amount"],
          "newAmount" => params["amount"]
        })

      item["amount"] > params["amount"] ->
        Spear.Event.new("ItemQuantityDecreased", %{
          "name" => item["name"],
          "previousAmount" => item["amount"],
          "newAmount" => params["amount"]
        })

      item["amount"] == params["amount"] ->
        nil
    end
  end

  def remove_item(current_cart, name) do
    if Enum.find(current_cart["items"], &(&1["name"] == name)) do
      Spear.Event.new("ItemRemoved", %{"name" => name})
    else
      nil
    end
  end

  def empty_cart(current_cart) do
    if current_cart["items"] != [] do
      Spear.Event.new("CartEmptied", [])
    else
      nil
    end
  end

  def add_discount_coupon(current_cart, coupon) do
    if !current_cart["coupon"] do
      Spear.Event.new("CouponAdded", %{"percentage" => coupon})
    else
      nil
    end
  end

  def remove_discount_coupon(current_cart) do
    if current_cart["coupon"] do
      Spear.Event.new("CouponRemoved", %{"coupon" => current_cart["coupon"]})
    else
      nil
    end
  end

  def build_cart_from_stream(stream) do
    Enum.reduce(stream, %{}, fn current_event, acc ->
      case current_event.type do
        "CartCreated" ->
          current_event.body

        "ItemAdded" ->
          Map.put(acc, "items", [current_event.body | acc["items"]])

        "ItemQuantityIncreased" ->
          item_index = Enum.find_index(acc["items"], &(&1["name"] == current_event.body["name"]))

          updated_items =
            List.update_at(
              acc["items"],
              item_index,
              &Map.put(&1, "amount", current_event.body["newAmount"])
            )

          Map.put(acc, "items", updated_items)

        "ItemQuantityDecreased" ->
          item_index = Enum.find_index(acc["items"], &(&1["name"] == current_event.body["name"]))

          updated_items =
            List.update_at(
              acc["items"],
              item_index,
              &Map.put(&1, "amount", current_event.body["newAmount"])
            )

          Map.put(acc, "items", updated_items)

        "ItemRemoved" ->
          Map.put(
            acc,
            "items",
            Enum.filter(acc["items"], &(&1["name"] != current_event.body["name"]))
          )

        "CartEmptied" ->
          Map.put(acc, "items", [])

        "CouponAdded" ->
          Map.put(acc, "coupon", current_event.body)

        "CouponRemoved" ->
          Map.put(acc, "coupon", nil)

        _ ->
          acc
      end
    end)
  end

  def calculate_cart_total(stream) do
    cart_before_checkout =
      Enum.reduce(
        stream,
        %{
          "sub_total" => 0,
          "coupon" => nil,
          "items" => []
        },
        fn current_event, acc ->
          case current_event.type do
            "CartCreated" ->
              acc

            "ItemAdded" ->
              new_acc = Map.put(acc, "items", [current_event.body | acc["items"]])

              item_total = current_event.body["price"] * current_event.body["amount"]
              Map.put(new_acc, "sub_total", acc["sub_total"] + item_total)

            "ItemQuantityIncreased" ->
              item_index =
                Enum.find_index(acc["items"], &(&1["name"] == current_event.body["name"]))

              updated_items =
                List.update_at(
                  acc["items"],
                  item_index,
                  &Map.put(&1, "amount", current_event.body["newAmount"])
                )

              sub_total =
                Enum.reduce(updated_items, 0, fn item, sum ->
                  sum + item["price"] * item["amount"]
                end)

              acc
              |> Map.put("items", updated_items)
              |> Map.put("sub_total", sub_total)

            "ItemQuantityDecreased" ->
              item_index =
                Enum.find_index(acc["items"], &(&1["name"] == current_event.body["name"]))

              updated_items =
                List.update_at(
                  acc["items"],
                  item_index,
                  &Map.put(&1, "amount", current_event.body["newAmount"])
                )

              sub_total =
                Enum.reduce(updated_items, 0, fn item, sum ->
                  sum + item["price"] * item["amount"]
                end)

              acc
              |> Map.put("items", updated_items)
              |> Map.put("sub_total", sub_total)

            "ItemRemoved" ->
              new_acc =
                Map.put(
                  acc,
                  "items",
                  Enum.filter(acc["items"], &(&1["name"] != current_event.body["name"]))
                )

              Map.put(
                new_acc,
                "sub_total",
                Enum.reduce(new_acc["items"], 0, fn item, sum ->
                  sum + item["price"] * item["amount"]
                end)
              )

            "CartEmptied" ->
              acc
              |> Map.put("items", [])
              |> Map.put("sub_total", 0)

            "CouponAdded" ->
              Map.put(acc, "coupon", current_event.body)

            "CouponRemoved" ->
              Map.put(acc, "coupon", nil)

            _ ->
              acc
          end
        end
      )

    if cart_before_checkout["coupon"] do
      percent_to_pay = 1 - cart_before_checkout["coupon"]["percentage"] / 100
      cart_before_checkout["sub_total"] * percent_to_pay
    else
      cart_before_checkout["sub_total"]
    end
  end
end
