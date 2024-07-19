const UsdhToken = artifacts.require("UsdhToken");
const Web3 = require('web3');

module.exports = async function(deployer, network, accounts) {
    const num = Web3.utils.toBN('10000000000000000');

    let validatorInstance = await deployer.deploy(
            UsdhToken,
            num,
            "Ho USD",
            "USDH",
            6,
            {overwrite:true, from:accounts[0]});
     console.log(validatorInstance);


};
