-module(prices).

-export([start/0]).

-record(product, {product_type,
                  product_code,
                  supplier_id,
                  description,
                  delivery_date,
                  cost_price,
                  unit_count,
                  sell_price,
                  sell_by_date}).

start() ->
  {ok, InputFile}  = file:open("../produce.csv", [read]),
  {ok, OutputFile} = file:open("pricefile.txt", [write]),
  {ok, _Header} = file:read_line(InputFile),
  ok = process_file(InputFile, OutputFile),
  ok.

process_file(InputFile, OutputFile) ->
  case file:read_line(InputFile) of
    {ok, Line} ->
      process_file(InputFile, OutputFile, Line);
    eof ->
      ok
  end.

process_file(InputFile, OutputFile, Line) ->
  to_price_file(string:strip(Line, right, $\n), OutputFile),
  process_file(InputFile, OutputFile).

to_price_file(Line, OutputFile) ->
  Fields = csv:parse_line(Line),
  [SupplierID, ProductCode, Description, DeliveryDate, CostPrice, UnitCount] = Fields,
  Product = calculate_product(list_to_integer(SupplierID),list_to_integer(ProductCode),
                              Description, date_utils:parse_date(DeliveryDate),
                              list_to_integer(CostPrice), list_to_integer(UnitCount)),
  ok = write_pricefile(Product, OutputFile),
  ok.

calculate_product(SupplierID, ProductCode, Description, DeliveryDate, CostPrice, UnitCount) ->
  Product    = simple_product(SupplierID, ProductCode, Description, DeliveryDate, CostPrice, UnitCount),
  SellPrice  = sell_price(Product#product.product_type, CostPrice),
  SellByDate = sell_by_date(Product#product.product_type, SupplierID, DeliveryDate),
  Product#product{sell_price = SellPrice, sell_by_date=SellByDate}.

sell_price(ProductType, CostPrice) ->
  CostPrice + markup(ProductType, CostPrice).

sell_by_date(ProductType, SupplierID, DeliveryDate) ->
  date_utils:date_add_days(DeliveryDate, shelf_days(SupplierID, ProductType)).

simple_product(SupplierID, ProductCode, Description, DeliveryDate, CostPrice, UnitCount) ->
  #product{product_type  = product_type(ProductCode),
           product_code  = ProductCode,
           supplier_id   = SupplierID,
           description   = Description,
           delivery_date = DeliveryDate,
           cost_price    = CostPrice,
           unit_count    = UnitCount}.

markup(apple, CostPrice) ->
  CostPrice * (40/100.0);
markup(banana, CostPrice) ->
  CostPrice * (35/100.0);
markup(berry, CostPrice) ->
  CostPrice * (55/100.0);
markup(_ProductType, CostPrice) ->
  CostPrice * (50/100.0).

shelf_days(32, ProductType) ->
  shelf_days(ProductType) - 3;
shelf_days(_SupplierID, ProductType) ->
  shelf_days(ProductType).

shelf_days(apple)        -> 14;
shelf_days(banana)       -> 5;
shelf_days(_ProductType) -> 7.

product_type(ProductCode) when ((ProductCode >= 1100) and (ProductCode =< 1199)) ->
  apple;
product_type(ProductCode) when ((ProductCode >= 1200) and (ProductCode =< 1299)) ->
  banana;
product_type(ProductCode) when ((ProductCode >= 1300) and (ProductCode =< 1399)) ->
  berry.

write_pricefile(Product, OutputFile) ->
  SellPriceRands   = io_lib:format("~.2f", [Product#product.sell_price/100]),
  [SpaceChar] = " ",
  LabelSellPrice   = "R"++ string:right(SellPriceRands, 4, SpaceChar),
  LabelSellByDate  = date_utils:date_to_string(Product#product.sell_by_date),
  LabelDescription = string:substr(Product#product.description, 1, 31),
  Line = LabelSellPrice ++ LabelSellByDate ++ LabelDescription ++ "\n",
  Lines = [Line || _Count <- lists:seq(1,Product#product.unit_count)],
  ok = file:write(OutputFile, Lines),
  ok.
