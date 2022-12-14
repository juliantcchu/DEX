// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import './token.sol';
import "hardhat/console.sol";


contract TokenExchange is Ownable {
    string public exchange_name = '';

    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;                                  // TODO: paste token contract address here

    //exchangeContract address: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

    Token public token = Token(tokenAddr);                                

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    mapping(address => uint) private lps; 
     
    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;    

    // liquidity rewards
    uint private swap_fee_numerator = 5;                // TODO Part 5: Set liquidity providers' returns.
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    constructor() {}
    

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        onlyOwner
    {
        console.log('amountTokens', amountTokens);
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;
    }

    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(index < lp_providers.length, "specified index is larger than the number of lps");
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }



    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    
    /* ========================= Liquidity Provider Functions =========================  */ 

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate) 
        external 
        payable
    {
        /******* TODO: Implement this function *******/


        // require(address(msg.sender).balance >= msg.value, 'unsufficient balance of Eth'); 

        // update reserves
        uint amount_eth;
        uint amount_token;

        console.log('running addLiquidity');

        amount_eth = msg.value;
        amount_token = amount_eth * token_reserves / eth_reserves;

        console.log(amount_eth, amount_token, eth_reserves, token_reserves);
        console.log(10000 * eth_reserves / token_reserves);

        require(max_exchange_rate >= amount_token * 100 / amount_eth, "exceeded max_exchange_rate");
        require(min_exchange_rate <= amount_token * 100 / amount_eth, "exceeded max_exchange_rate");

        require(token.balanceOf(msg.sender) >= amount_token, 'insufficient token balance');

        // payable(msg.sender).transfer(amount_eth);
        token.transferFrom(msg.sender, address(this), amount_token);

        console.log('funds transferred');
        
        // update liquidity provider stakes
        // amount eth 

        // lps ---- 10000 is the constant denominator
        uint myStake = 10000 * amount_eth / eth_reserves;

        console.log(myStake);

        bool new_provider = true;
        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] == msg.sender) {
                 new_provider = false;
                 // update my stake
                 lps[lp_providers[i]] = lps[lp_providers[i]] * (eth_reserves - amount_eth) / eth_reserves + myStake;
            }else{
                // update other existing providers stakes
                lps[lp_providers[i]] = lps[lp_providers[i]] * (eth_reserves - amount_eth) / eth_reserves;
            }

            console.log(lps[lp_providers[i]]);
        }

        if (new_provider){
            lp_providers.push(msg.sender);
            lps[msg.sender] = myStake;
        }

        eth_reserves = address(this).balance; // amountETH; 
        token_reserves = token.balanceOf(address(this));

        k = eth_reserves * token_reserves;

        console.log(eth_reserves, token_reserves, k);
       
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint max_exchange_rate, uint min_exchange_rate)
        public 
        payable
    {
        /******* TODO: Implement this function *******/

        // reduce stake of sender and increase everyone elses

        uint amountToken = amountETH * eth_reserves / token_reserves;

        require(amountToken < token_reserves, "cant deplete token reserves to zero");
        require(amountETH < eth_reserves, "cant deplete eth reserves to zero");

        require(max_exchange_rate >= amountToken * 100 / amountToken, "exceeded max_exchange_rate");
        require(min_exchange_rate <= amountToken * 100 / amountToken, "exceeded max_exchange_rate");


        uint points_deducted = amountETH * 10000 / eth_reserves;
        lps[msg.sender] -= points_deducted;
        require(lps[msg.sender] > 0, 'insufficient stake');


        uint factor = 10000 - points_deducted;

        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] != msg.sender) {
                lps[lp_providers[i]] = lps[lp_providers[i]] * 10000 / factor;
            }
        }

        payable(msg.sender).transfer(amountETH);
        token.transfer(msg.sender, amountToken);


        eth_reserves = address(this).balance; // amountETH; 
        token_reserves = token.balanceOf(address(this));
        k = eth_reserves * token_reserves;

    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {
        /******* TODO: Implement this function *******/

        // reduce stake of sender and increase everyone else

        uint amountETH = eth_reserves * lps[msg.sender] / 10000;
        uint amountToken = token_reserves * lps[msg.sender] / 10000;
        
        require(amountToken < token_reserves, "cant deplete token reserves to zero");
        require(amountETH < eth_reserves, "cant deplete eth reserves to zero");

        require(max_exchange_rate >= amountToken * 100 / amountToken, "exceeded max_exchange_rate");
        require(min_exchange_rate <= amountToken * 100 / amountToken, "exceeded max_exchange_rate");

        uint factor = 10000 - lps[msg.sender];

        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] != msg.sender) {
                lps[lp_providers[i]] = lps[lp_providers[i]] * 10000 / factor;
            }
        }

        payable(msg.sender).transfer(amountETH);
        token.transfer(msg.sender, amountToken);

        eth_reserves = address(this).balance; // amountETH; 
        token_reserves = token.balanceOf(address(this));
        k = eth_reserves * token_reserves;

        lps[msg.sender] = 0;
        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] == msg.sender) {
                removeLP(i);
                return;
            }
        }
    
    }
    /***  Define additional functions for liquidity fees here as needed ***/


    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint max_exchange_rate)
        external 
        payable
    {
        /******* TODO: Implement this function *******/

        uint amountETH;
        

        //calculate amountETH using constant product formula

        amountETH = eth_reserves - k / (token_reserves + amountTokens);
        amountETH -= amountETH * swap_fee_numerator / swap_fee_denominator;

        require(amountTokens * 100 / amountETH <= max_exchange_rate, 'exceeded max exchange rate');

        require(amountETH < eth_reserves, "must not deplete eth reserves to zero");
        
        // transfer
        require(token.balanceOf(msg.sender) >= amountTokens, "user token balance insuffienct");
        token.transferFrom(msg.sender, address(this), amountTokens);
        payable(msg.sender).transfer(amountETH);


        //update balance
        eth_reserves = address(this).balance; // amountETH; 
        token_reserves = token.balanceOf(address(this));
        k = eth_reserves * token_reserves;


    }



    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate)
        external
        payable 
    {
        /******* TODO: Implement this function *******/

        uint amountTokens;
        uint amountETH = msg.value;

        // calculate amountToken

        amountTokens = token_reserves - k / (eth_reserves + amountETH);
        amountTokens -= amountTokens * swap_fee_numerator / swap_fee_denominator;
        require(amountETH *100 / amountTokens <= max_exchange_rate, 'exceeded max exchange rate');
        
        require(amountTokens < token_reserves, "must not deplete token reserves to zero");

        //update reserves
        // eth_reserves += amountETH;
        // token_reserves -= amountTokens;

        console.log('transferring', msg.sender, amountTokens);

        token.transfer(msg.sender, amountTokens);

        eth_reserves = address(this).balance; // amountETH; 
        token_reserves = token.balanceOf(address(this));
        k = eth_reserves * token_reserves;
    }
}

