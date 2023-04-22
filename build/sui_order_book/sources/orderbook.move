module sui_order_book::orderbook {
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use std::vector;
    use sui::math;
    // Define a token pair struct to represent the trading pair in the order book
    struct TokenPair has drop, store {
        token1: vector<u8>,
        token2: vector<u8>,
    }
    // Define an order struct to represent an order in the order book
    struct Order has drop, store {
        price: u128,
        amount: u64,
        maker: address,
        filled_amount: u64,
    }
    // Define an order book struct to represent the order book for a token pair
    struct OrderBook has drop, store  {
        bids: vector<Order>, // map bid order ID to bid order
        asks: vector<Order>, // map ask order ID to ask order
    }
    // Define a mapping from token pair to order book
    // Note: This is a global storage resource
    struct OrderBooks has store {
        token_pairs: Table<u64, TokenPair>,
        order_books: Table<u64, OrderBook>,
    }
    fun order_books(ctx: &mut TxContext): OrderBooks {
        OrderBooks { 
            token_pairs: table::new(ctx), 
            order_books: table::new(ctx), 
        } 
    }
    fun drop(order_books_: OrderBooks) {
        let OrderBooks { token_pairs, order_books } = order_books_;
        table::drop(token_pairs);
        table::drop(order_books);
    }
    // Intiate Token Pair
    fun token_pair(token1: vector<u8>, token2: vector<u8>): TokenPair {
        TokenPair {
            token1,
            token2,
        }
    }
    fun init_order_book(): OrderBook {
        OrderBook{
            bids: vector::empty(),
            asks: vector::empty(),
        }
    }
    fun create_new_token_pair(
        self: &mut OrderBooks, 
        symbol_t: vector<u8>,
        symbol_p: vector<u8>,
    ): u64 {
        let pair_id = table::length(&self.token_pairs) + 1;
        table::add(&mut self.token_pairs, pair_id, token_pair(symbol_t, symbol_p));
        table::add(&mut self.order_books, pair_id, init_order_book());
        pair_id
    }
    // Partition the array and return the index of the pivot
    fun partition(list: &mut vector<Order>, low: u64, high: u64, ascending: bool): u64 {
        let pivot_price = vector::borrow(list, high).price;
        let i = low;
        let j = low;
        while (j <= high) {
            let price = vector::borrow(list, j).price;
            if ((ascending && price < pivot_price) || (!ascending && price > pivot_price)) {
                vector::swap(list, i, j);
                i = i + 1;
            };
            j = j + 1;
        };
        vector::swap(list, i, high);
        return i
    }
    // Perform the quicksort algorithm recursively
    fun quicksort(list: &mut vector<Order>, low: u64, high: u64, ascending: bool) {
        if (low < high) {
            let pivot_idx = partition(list, low, high, ascending);
            if (pivot_idx > 0) {
                quicksort(list, low, pivot_idx - 1, ascending);
            };
            quicksort(list, pivot_idx + 1, high, ascending);
        }
    }
    // Interface for sorting a vector of Order using quicksort
    fun sort(list: &mut vector<Order>, ascending: bool) {
        let length = vector::length(list);
        quicksort(list, 0, (length - 1), ascending);
    }
    // Print function to debug bid / ask values
    fun print(list: &mut vector<Order>) {
        let i = 0;
        let l = vector::length(list);
        std::debug::print(&std::ascii::string(b"-----START-----:"));
        while (i < l) {
            let price = vector::borrow(list, i).price;
            let amount = vector::borrow(list, i).amount;
            let filled_amount = vector::borrow(list, i).filled_amount;
            std::debug::print(&price);
            std::debug::print(&amount);
            std::debug::print(&filled_amount);
            i = i + 1;
        };
        std::debug::print(&std::ascii::string(b"-----END-----:"));
    }
    // Define a function to submit a bid order to the order book
    // This function takes in the token pair, price, and amount of the bid order,
    // as well as the address of the maker (i.e., the user who submitted the order)
    // It generates a unique ID for the order and adds it to the bid side of the order book
    public fun submit_bid_order(self: &mut OrderBooks, pair_id: u64, price: u128, amount: u64, maker: address) {
        // Get the order book for the token pair
        let order_book = table::borrow_mut(&mut self.order_books, pair_id);
        // Create the bid order
        let bid_order = Order{
            price: price,
            amount: amount,
            maker: maker,
            filled_amount: 0,
        };
        // Add the bid order to the bid side of the order book
        vector::push_back(&mut order_book.bids, bid_order);
    }
    // Define a function to submit an ask order to the order book
    // This function takes in the token pair, price, and amount of the ask order,
    // as well as the address of the maker (i.e., the user who submitted the order)
    // It generates a unique ID for the order and adds it to the ask side of the order book
    public fun submit_ask_order(self: &mut OrderBooks, pair_id: u64, price: u128, amount: u64, maker: address) {
        // Get the order book for the token pair
        let order_book = table::borrow_mut(&mut self.order_books, pair_id);
        // Create the ask order
        let ask_order = Order{
            price: price,
            amount: amount,
            maker: maker,
            filled_amount: 0,
        };
        // Add the ask order to the ask side of the order book
        vector::push_back(&mut order_book.asks, ask_order);
    }
    // Define a function to match bid orders with ask orders in the order book
    // This function takes in the token pair and the amount of the bid order that needs to be filled
    // It matches the bid order with the best available ask orders in the order book
    // It fills the bid order and ask orders that are fully filled, and partially fills the rest
    public fun match_orders(self: &mut OrderBooks, pair_id: u64) {
        // Get the order book for the token pair
        let order_book = table::borrow_mut(&mut self.order_books, pair_id);
        // Sort ask orders in ascending order by price
        sort(&mut order_book.asks, true);
        // Sort bid orders in descending order by price
        sort(&mut order_book.bids, false);
        //print(&mut order_book.asks);
        //print(&mut order_book.bids);
        // Iterate through the bid and ask orders
        let i = 0;
        let j = 0;
        while (i < vector::length(&order_book.bids) && j < vector::length(&order_book.asks)) {
            let bid_order = vector::borrow_mut(&mut order_book.bids, i);
            let ask_order = vector::borrow_mut(&mut order_book.asks, j);

            // Check if the bid price is greater than or equal to the ask price
            if (bid_order.price >= ask_order.price) {
                // Calculate the matched amount
                let matched_amount = math::min((bid_order.amount - bid_order.filled_amount), (ask_order.amount - ask_order.filled_amount));
                //std::debug::print(&matched_amount);
                // Update the filled_amount of the bid and ask orders
                bid_order.filled_amount = bid_order.filled_amount + matched_amount;
                ask_order.filled_amount = ask_order.filled_amount + matched_amount;

                // Check if the bid order is fully filled
                if (bid_order.filled_amount == bid_order.amount) {
                    // Remove the bid order from the order book
                    vector::remove(&mut order_book.bids, i);
                };

                // Check if the ask order is fully filled
                if (ask_order.filled_amount == ask_order.amount) {
                    // Remove the ask order from the order book
                    vector::remove(&mut order_book.asks, j);
                };
            } else {
                break
            };
            //print(&mut order_book.asks);
            //print(&mut order_book.bids);
        };
    }
    public fun match_all_pairs(self: &mut OrderBooks) {
        let l = table::length(&self.order_books);
        let pair_id = 1;
        while (pair_id <= l && table::contains(&self.order_books, pair_id)) {
            match_orders(self, pair_id);
            pair_id = pair_id + 1;
        }
    }
    #[test]
    public fun test_match_orders_balanced_orders() {
        use sui::test_utils::{Self, assert_eq};
        // Initialize the OrderBooks and create a new token pair
        let order_books = order_books(&mut tx_context::dummy());
        let pair_id = create_new_token_pair(
            &mut order_books,
            b"COIN1",
            b"COIN2",
        );
        // Create bid and ask orders
        submit_ask_order(&mut order_books, pair_id, 800, 5, @0x456);
        submit_ask_order(&mut order_books, pair_id, 800, 15, @0xabc);
        submit_bid_order(&mut order_books, pair_id, 800, 5, @0x123);
        submit_bid_order(&mut order_books, pair_id, 800, 15, @0x789);

        // Match orders
        match_orders(&mut order_books, pair_id);

        // Check if the orders are matched correctly
        let order_book = table::borrow(&order_books.order_books, 1);
        test_utils::assert_eq(vector::length(&order_book.bids), 0);
        assert_eq(vector::length(&order_book.asks), 0);
        drop(order_books)
    }
    #[test]
    public fun test_match_orders_asks_filled_partially() {
        use sui::test_utils::{Self, assert_eq};
        // Initialize the OrderBooks and create a new token pair
        let order_books = order_books(&mut tx_context::dummy());
        let pair_id = create_new_token_pair(
            &mut order_books,
            b"COIN1",
            b"COIN2",
        );
        // Create bid and ask orders
        submit_ask_order(&mut order_books, pair_id, 800, 5, @0x456);
        submit_ask_order(&mut order_books, pair_id, 1100, 15, @0xabc);
        submit_bid_order(&mut order_books, pair_id, 1000, 10, @0x123);
        submit_bid_order(&mut order_books, pair_id, 900, 20, @0x789);

        // Match orders
        match_orders(&mut order_books, pair_id);

        // Check if the orders are matched correctly
        let order_book = table::borrow(&order_books.order_books, 1);
        test_utils::assert_eq(vector::length(&order_book.asks), 1);
        test_utils::assert_eq(vector::length(&order_book.bids), 2);

        let remaining_ask_order = vector::borrow(&order_book.asks, 0);
        let remaining_bid_order1 = vector::borrow(&order_book.bids, 0);
        let remaining_bid_order2 = vector::borrow(&order_book.bids, 1);

        assert_eq(remaining_ask_order.price, 1100);
        assert_eq(remaining_ask_order.amount, 15);
        assert_eq(remaining_ask_order.maker, @0xabc);
        assert_eq(remaining_ask_order.filled_amount, 0);

        assert_eq(remaining_bid_order1.price, 1000);
        assert_eq(remaining_bid_order1.amount, 10);
        assert_eq(remaining_bid_order1.maker, @0x123);
        assert_eq(remaining_bid_order1.filled_amount, 5);

        assert_eq(remaining_bid_order2.price, 900);
        assert_eq(remaining_bid_order2.amount, 20);
        assert_eq(remaining_bid_order2.maker, @0x789);
        assert_eq(remaining_bid_order2.filled_amount, 0);
        drop(order_books)
    }
    #[test]
    public fun test_match_orders_all_asks_filled() {
        use sui::test_utils::{Self, assert_eq};
        // Initialize the OrderBooks and create a new token pair
        let order_books = order_books(&mut tx_context::dummy());
        let pair_id = create_new_token_pair(
            &mut order_books,
            b"COIN1",
            b"COIN2",
        );
        // Create bid and ask orders
        submit_ask_order(&mut order_books, pair_id, 800, 5, @0x456);
        submit_ask_order(&mut order_books, pair_id, 900, 15, @0xabc);
        submit_bid_order(&mut order_books, pair_id, 1000, 10, @0x123);
        submit_bid_order(&mut order_books, pair_id, 900, 20, @0x789);

        // Match orders
        match_orders(&mut order_books, pair_id);

        // Check if the orders are matched correctly
        let order_book = table::borrow(&order_books.order_books, 1);
        test_utils::assert_eq(vector::length(&order_book.asks), 0);
        test_utils::assert_eq(vector::length(&order_book.bids), 1);

        let remaining_bid_order = vector::borrow(&order_book.bids, 0);

        assert_eq(remaining_bid_order.price, 900);
        assert_eq(remaining_bid_order.amount, 20);
        assert_eq(remaining_bid_order.maker, @0x789);
        assert_eq(remaining_bid_order.filled_amount, 10);
        drop(order_books)
    }
    #[test]
    public fun test_match_orders_match_multiple_pairs() {
        use sui::test_utils::{Self, assert_eq};
        // Initialize the OrderBooks and create a new token pair
        let order_books = order_books(&mut tx_context::dummy());
        let pair_id1 = create_new_token_pair(
            &mut order_books,
            b"COIN1",
            b"COIN2",
        );
        // Create bid and ask orders
        submit_ask_order(&mut order_books, pair_id1, 800, 5, @0x456);
        submit_ask_order(&mut order_books, pair_id1, 900, 15, @0xabc);
        submit_bid_order(&mut order_books, pair_id1, 1000, 10, @0x123);
        submit_bid_order(&mut order_books, pair_id1, 900, 20, @0x789);

        let pair_id2 = create_new_token_pair(
            &mut order_books,
            b"COIN3",
            b"COIN4",
        );
        // Create bid and ask orders
        submit_ask_order(&mut order_books, pair_id2, 1800, 5, @0x456);
        submit_ask_order(&mut order_books, pair_id2, 1200, 15, @0xabc);
        submit_bid_order(&mut order_books, pair_id2, 1500, 10, @0x123);
        submit_bid_order(&mut order_books, pair_id2, 1900, 20, @0x789);
        // Match orders
        match_all_pairs(&mut order_books);

        // Check if the orders are matched correctly
        let order_book = table::borrow(&order_books.order_books, pair_id1);
        test_utils::assert_eq(vector::length(&order_book.asks), 0);
        test_utils::assert_eq(vector::length(&order_book.bids), 1);

        let remaining_bid_order = vector::borrow(&order_book.bids, 0);

        assert_eq(remaining_bid_order.price, 900);
        assert_eq(remaining_bid_order.amount, 20);
        assert_eq(remaining_bid_order.maker, @0x789);
        assert_eq(remaining_bid_order.filled_amount, 10);

        // Check if the orders are matched correctly
        let order_book = table::borrow(&order_books.order_books, pair_id2);
        test_utils::assert_eq(vector::length(&order_book.asks), 0);
        test_utils::assert_eq(vector::length(&order_book.bids), 1);

        let remaining_bid_order = vector::borrow(&order_book.bids, 0);

        assert_eq(remaining_bid_order.price, 1500);
        assert_eq(remaining_bid_order.amount, 10);
        assert_eq(remaining_bid_order.maker, @0x123);
        assert_eq(remaining_bid_order.filled_amount, 0);
        drop(order_books)
    }
}