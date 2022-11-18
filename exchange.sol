// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import './token.sol';
import "hardhat/console.sol";


contract TokenExchange is Ownable {
    string public exchange_name = '';

    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;                                  // TODO: paste token contract address here
    Token public token = Token(tokenAddr);                                

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;
    
    // Temporarily save exchange fee
    uint private uninvested_ETH = 0;
    uint private uninvested_token = 0;

    mapping(address => uint) private lps;
    mapping(address => mapping(string => uint)) private lpr;        // liquidity provider reward
    uint MULTIPLIER = 100000;
    uint PCT = 100;
     
    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;                     

    // liquidity rewards
    uint private swap_fee_numerator = 2;                // TODO Part 5: Set liquidity providers' returns.
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
        uint equivalent_token = msg.value*token_reserves*PCT/eth_reserves;
        require(equivalent_token >= min_exchange_rate*msg.value, "exchange rate too low");
        require(equivalent_token <= max_exchange_rate*msg.value, "exchange rate too high");
        equivalent_token /= PCT;
        require(token.allowance(msg.sender, address(this)) >= equivalent_token, "not enough token in account");
        token.transferFrom(msg.sender, address(this), equivalent_token);
        token_reserves += equivalent_token;
        for (uint idx = 0; idx < lp_providers.length; idx++) {
            lps[lp_providers[idx]] = lps[lp_providers[idx]] * eth_reserves / (eth_reserves+msg.value);
        }
        bool sender_in_lps = false;
        for (uint idx = 0; idx < lp_providers.length; idx++) {
            if (lp_providers[idx] == msg.sender) {
                sender_in_lps = true;
                break;
            }
        }
        if (!sender_in_lps) {
            lp_providers.push(msg.sender);
        }
        eth_reserves += msg.value;
        lps[msg.sender] += msg.value*MULTIPLIER/eth_reserves;
        k = address(this).balance*token.balanceOf(address(this));
        // assert(token_reserves == token.balanceOf(address(this)));
        // assert(eth_reserves == address(this).balance);
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint max_exchange_rate, uint min_exchange_rate)
        public 
        payable
    {
        /******* TODO: Implement this function *******/
        require(amountETH < eth_reserves, "not enough ETH in pool");
        uint equivalent_token = amountETH*token_reserves*PCT/eth_reserves;
        require(equivalent_token >= min_exchange_rate*amountETH, "exchange rate too low");
        require(equivalent_token <= max_exchange_rate*amountETH, "exchange rate too high");
        equivalent_token /= PCT;
        require(equivalent_token < token_reserves, "not enough token in pool");
        require(lps[msg.sender] >= amountETH*MULTIPLIER/eth_reserves, "not enough liquidity in account");
        lps[msg.sender] -= amountETH*MULTIPLIER/eth_reserves;
        if (lps[msg.sender] == 0) {
            for (uint idx = 0; idx < lp_providers.length; idx++){
                if (lp_providers[idx] == msg.sender) {
                    removeLP(idx);
                    break;
                }
            }
        }
        for (uint idx = 0; idx < lp_providers.length; idx++){
            lps[lp_providers[idx]] = lps[lp_providers[idx]] * eth_reserves / (eth_reserves-amountETH);
        }
        token.transfer(msg.sender, equivalent_token);
        token_reserves -= equivalent_token;
        payable(msg.sender).transfer(amountETH);
        eth_reserves -= amountETH;
        k = address(this).balance*token.balanceOf(address(this));
        // assert(token_reserves == token.balanceOf(address(this)));
        // assert(eth_reserves == address(this).balance);
    }
    // function removeLiquidity(uint amountETH, uint max_exchange_rate, uint min_exchange_rate)
    //     public 
    //     payable
    // {
    //     /******* TODO: Implement this function *******/
    //     require(amountETH < address(this).balance, "not enough ETH in pool");
    //     uint equivalent_token = amountETH*token.balanceOf(address(this))*PCT/address(this).balance;
    //     require(equivalent_token >= min_exchange_rate*amountETH, "exchange rate too low");
    //     require(equivalent_token <= max_exchange_rate*amountETH, "exchange rate too high");
    //     uint reward_token = lpr[msg.sender]["token"]*PCT*amountETH/(swap_fee_denominator*lps[msg.sender]*address(this).balance); // compute reward in token
    //     uint reward_ETH = lpr[msg.sender]["ETH"]*PCT*amountETH/(swap_fee_denominator*lps[msg.sender]*address(this).balance); // compute reward in ETH
    //     equivalent_token = (equivalent_token+reward_token)/PCT;
    //     amountETH += reward_ETH/swap_fee_denominator;
    //     require(equivalent_token < token.balanceOf(address(this)), "not enough token in pool");
    //     require(lps[msg.sender] >= amountETH*MULTIPLIER/address(this).balance, "not enough liquidity in account");
    //     lps[msg.sender] -= amountETH*MULTIPLIER/address(this).balance;
    //     lpr[msg.sender]["token"] -= reward_token;
    //     lpr[msg.sender]["ETH"] -= reward_ETH;
    //     if (lps[msg.sender] == 0) {
    //         for (uint idx = 0; idx < lp_providers.length; idx++){
    //             if (lp_providers[idx] == msg.sender) {
    //                 removeLP(idx);
    //                 break;
    //             }
    //         }
    //     }
    //     for (uint idx = 0; idx < lp_providers.length; idx++){
    //         lps[lp_providers[idx]] = lps[lp_providers[idx]] * eth_reserves / (eth_reserves-amountETH);
    //     }
    //     token.transfer(msg.sender, equivalent_token);
    //     token_reserves -= equivalent_token;
    //     payable(msg.sender).transfer(amountETH);
    //     eth_reserves -= amountETH;
    //     k = address(this).balance*token.balanceOf(address(this));
    //     // assert(token_reserves == token.balanceOf(address(this)));
    //     // assert(eth_reserves == address(this).balance);
    // }
    

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {
        /******* TODO: Implement this function *******/
        uint amountETH = lps[msg.sender]*eth_reserves/MULTIPLIER;
        removeLiquidity(amountETH, max_exchange_rate, min_exchange_rate);
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
        // console.log(max_exchange_rate,amountTokens);
        require(amountTokens <= token.balanceOf(msg.sender), "not enough token for exchange in your account");
        uint equivalent_ETH = eth_reserves*amountTokens*PCT/(token_reserves+amountTokens);
        require(equivalent_ETH <= max_exchange_rate*amountTokens, "exchange rate too high");
        equivalent_ETH /= PCT;
        require(equivalent_ETH < eth_reserves, "not enough ETH for exchange in pool");
        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves += amountTokens;
        payable(msg.sender).transfer(equivalent_ETH);
        eth_reserves -= equivalent_ETH;
        // assert(token_reserves == token.balanceOf(address(this)));
        // assert(eth_reserves == address(this).balance);
    }
    // function swapTokensForETH(uint amountTokens, uint max_exchange_rate)
    //     external 
    //     payable
    // {
    //     /******* TODO: Implement this function *******/
    //     require(amountTokens <= token.balanceOf(msg.sender), "not enough token for exchange in your account");
    //     uint swap_fee_token = amountTokens*swap_fee_numerator;
    //     uint swap_fee_ETH = eth_reserves*PCT*amountTokens/((token_reserves+amountTokens)*swap_fee_denominator);
    //     uint equivalent_ETH = eth_reserves*amountTokens*PCT/(token_reserves+amountTokens);
    //     require(equivalent_ETH <= max_exchange_rate*amountTokens, "exchange rate too high");
    //     equivalent_ETH = (equivalent_ETH-swap_fee_ETH)/PCT;
    //     require(equivalent_ETH < eth_reserves, "not enough ETH for exchange in pool");
    //     token.transferFrom(msg.sender, address(this), amountTokens);
    //     payable(msg.sender).transfer(equivalent_ETH);
    //     eth_reserves -= equivalent_ETH;
    //     for (uint idx = 0; idx < lp_providers.length; idx++){
    //         lpr[lp_providers[idx]]["token"] += swap_fee_token * lps[lp_providers[idx]];
    //     }
    //     uninvested_token += swap_fee_token;
    //     token_reserves += amountTokens;
    //     uint ETH_to_invest = uninvested_token*eth_reserves/token_reserves;
    //     // compare uninvested token and uninvested eth. if uninvested eth < uninvested token, invest all uninvest eth. if uninvested eth > uninvested token, invest all uninvested token
    //     if (uninvested_ETH < ETH_to_invest){
    //         eth_reserves += uninvested_ETH/swap_fee_denominator;
    //         token_reserves += uninvested_ETH*token_reserves/(eth_reserves*swap_fee_denominator);
    //         uninvested_ETH = 0;
    //         uninvested_token -= uninvested_ETH*token_reserves/(eth_reserves*swap_fee_denominator);
    //     }else{
    //         eth_reserves += ETH_to_invest/swap_fee_denominator;
    //         token_reserves += uninvested_token/swap_fee_denominator;
    //         uninvested_token = 0;
    //         uninvested_ETH -= ETH_to_invest/swap_fee_denominator;
    //     }
    //     token_reserves -= swap_fee_token/swap_fee_denominator;
    //     // assert(token_reserves == token.balanceOf(address(this)));
    //     // assert(eth_reserves == address(this).balance);
    // }


    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate)
        external
        payable 
    {
        /******* TODO: Implement this function *******/
        uint equivalent_token = token_reserves*msg.value*PCT/(eth_reserves+msg.value);
        require(equivalent_token <= max_exchange_rate*msg.value, "exchange rate too high");
        equivalent_token /= PCT;
        require(equivalent_token < token_reserves, "not enough token for exchange in pool");
        eth_reserves += msg.value;
        token.transfer(msg.sender, equivalent_token);
        token_reserves -= equivalent_token;
        // assert(token_reserves == token.balanceOf(address(this)));
        // assert(eth_reserves == address(this).balance);
    }
    // function swapETHForTokens(uint max_exchange_rate)
    //     external
    //     payable 
    // {
    //     /******* TODO: Implement this function *******/
    //     uint swap_fee_ETH = msg.value*swap_fee_numerator;
    //     uint swap_fee_token = token_reserves*PCT*msg.value/((eth_reserves+msg.value)*swap_fee_denominator);
    //     uint equivalent_token = token_reserves*msg.value*PCT/(eth_reserves+msg.value);
    //     require(equivalent_token <= max_exchange_rate*msg.value, "exchange rate too high");
    //     equivalent_token = (equivalent_token-swap_fee_token)/PCT;
    //     require(equivalent_token < token_reserves, "not enough token for exchange in pool");
    //     token.transfer(msg.sender, equivalent_token);
    //     token_reserves -= equivalent_token;
    //     for (uint idx = 0; idx < lp_providers.length; idx++){
    //         lpr[lp_providers[idx]]["ETH"] += swap_fee_ETH * lps[lp_providers[idx]];
    //     }
    //     uninvested_ETH += swap_fee_ETH;
    //     eth_reserves += msg.value;
    //     uint token_to_invest = uninvested_ETH*token_reserves/eth_reserves;
    //     if (uninvested_token < token_to_invest) {
    //         token_reserves += uninvested_token/swap_fee_denominator;
    //         eth_reserves += uninvested_token*eth_reserves/(token_reserves*swap_fee_denominator);
    //         uninvested_token = 0;
    //         uninvested_ETH -= uninvested_token*eth_reserves/(token_reserves*swap_fee_denominator);
    //     }else{
    //         token_reserves += token_to_invest/swap_fee_denominator;
    //         eth_reserves += uninvested_ETH/swap_fee_denominator;
    //         uninvested_ETH = 0;
    //         uninvested_token -= token_to_invest/swap_fee_denominator;
    //     }
    //     eth_reserves -= swap_fee_ETH/swap_fee_denominator;
    //     // assert(token_reserves == token.balanceOf(address(this)));
    //     // assert(eth_reserves == address(this).balance);
    // }
}
