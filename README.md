# Order Book on Sui

## Description

This is a Move code implementing an order book that manages buy and sell orders for a token pair. It allows users to submit buy and sell orders for a given token pair and matches the orders according to the best available price in the order book.

The code consists of several structs and functions that define the data structures and the logic of the order book.

The TokenPair struct defines a trading pair with two tokens: token1 and token2.

The Order struct defines an order with a price, an amount, a maker address (i.e., the user who submitted the order), and a filled_amount field that keeps track of how much of the order has been filled.

The OrderBook struct defines the order book for a given token pair with two vectors of orders: bids for buy orders and asks for sell orders.

The OrderBooks struct defines a mapping from token pairs to order books.

The create_new_token_pair function adds a new token pair and order book to the OrderBooks mapping.

The submit_bid_order function adds a new buy order to the bid side of the order book.

The submit_ask_order function adds a new sell order to the ask side of the order book.

The match_orders function matches buy and sell orders in the order book and updates the order book accordingly.

The match_all_pairs function matches orders for all token pairs in the OrderBooks mapping.

The code also includes several test functions to ensure that the order book works correctly.

## Test Code

sui move test