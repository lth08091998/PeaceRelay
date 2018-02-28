pragma solidity ^0.4.8;

import "./SafeMath.sol";
import "./ERC20.sol";
import "./PeaceRelay.sol";
import "./RLP.sol";
import "./Ownable.sol";


contract ETCToken is ERC20, SafeMath, Ownable {
  using RLP for RLP.RLPItem;
  using RLP for RLP.Iterator;
  using RLP for bytes;
  
  struct Transaction {
    uint nonce;
    uint gasPrice;
    uint gasLimit;
    address to;
    uint value;
    bytes data;
  }

  struct ETCLockTxProof {
    bytes value;
    bytes32 blockhash;
    bytes path;
    bytes parentNodes;
  }

  // Public variables of the token
  string public name;
  string public symbol;
  uint8 public decimals;    //How many decimals to show.
  string public version = "v0.1";
  uint public totalSupply;
  uint public DEPOSIT_GAS_MINIMUM = 500000; //should be constant
  bytes4 public LOCK_FUNCTION_SIG = 0xf435f5a7;

  mapping(address => uint) balances;
  mapping(address => mapping (address => uint)) allowed;
  mapping(bytes32 => bool) rewarded;

  PeaceRelay public ETCRelay;
  address public etcLockingAddr; //maybe rename to EthLockingContract

  event Burn(address indexed from, address indexed etcAddr, uint indexed value);
  event Mint(address indexed to, uint value);

  function ETCToken(address peaceRelayAddr) {
    totalSupply = 0;
    name = "ETCToken";        // Set the name for display purposes
    symbol = "ETC";                       // Set the symbol for display purposes
    decimals = 9;                        // Amount of decimals for display purposes
    ETCRelay = PeaceRelay(peaceRelayAddr);
  }


  function setETCLockingAddr(address _etcLockingAddr) onlyOwner returns (bool) {
  	etcLockingAddr = _etcLockingAddr;
  	return true;
  }

  function mint(bytes value, uint256 blockHash, bytes path, bytes parentNodes) returns (bool) {
    if (!rewarded[keccak256(value, bytes32(blockHash), path, parentNodes)] && ETCRelay.checkTxProof(value, blockHash, path, parentNodes)) {
      Transaction memory tx = getTransactionDetails(value);
      bytes4 functionSig = getSignature(tx.data);

      require(functionSig == LOCK_FUNCTION_SIG);
      require(tx.to == etcLockingAddr);
      require(tx.gasLimit <= DEPOSIT_GAS_MINIMUM);

      address newAddress = getAddress(tx.data);

      totalSupply = safeAdd(totalSupply, tx.value);
      balances[newAddress] = safeAdd(balances[newAddress], tx.value);
      Mint(newAddress, tx.value);
      rewarded[keccak256(value, bytes32(blockHash), path, parentNodes)] = true;
      return true;
    }
    return false;
  }

  function burn(uint256 _value, address etcAddr) returns (bool) {
    // safeSub already has throw, so no need to throw
    balances[msg.sender] = safeSub(balances[msg.sender], _value);
    totalSupply = safeSub(totalSupply, _value);
    Burn(msg.sender, etcAddr, _value);
    return true;
  }
  
  function checkIfRewarded(bytes value, uint256 blockHash, bytes path, bytes parentNodes) constant returns (bool) {
    return rewarded[keccak256(value, bytes32(blockHash),path,parentNodes)];
  }
  
    function checkProof(bytes value, uint256 blockHash, bytes path, bytes parentNodes) constant returns (bool) {
    return ETCRelay.checkTxProof(value, blockHash, path, parentNodes);
  }
  
  function transfer(address _to, uint _value) returns (bool) {
    // safeSub already has throw, so no need to throw
    balances[msg.sender] = safeSub(balances[msg.sender], _value);
    balances[_to] = safeAdd(balances[_to], _value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  function transferFrom(address _from, address _to, uint _value) returns (bool) {
    var _allowance = allowed[_from][msg.sender];
    
    balances[_from] = safeSub(balances[_from], _value);
    allowed[_from][msg.sender] = safeSub(_allowance, _value);
    balances[_to] = safeAdd(balances[_to], _value);
    Transfer(_from, _to, _value);
    return true;
  }

  function balanceOf(address _owner) constant returns (uint) {
    return balances[_owner];
  }

  function approve(address _spender, uint _value) returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }


  function allowance(address _owner, address _spender) constant returns (uint) {
    return allowed[_owner][_spender];
  }

	// Non-payable unnamed function prevents Ether from being sent accidentally
	function () {}


  // HELPER FUNCTIONS
  function getSignature(bytes b) constant returns (bytes4) {
    require(b.length >= 32);
    uint tmp = 0;
    for (uint i = 0; i < 4; i++) {
       tmp = tmp*(2**8)+uint8(b[i]);
    }
    return bytes4(tmp);
  }

  //grabs the first input from some function data
  //and implies that it is an address
  function getAddress(bytes b) constant returns (address a) {
    if (b.length < 36) return address(0);
    assembly {
      let mask := 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
      a := and(mask, mload(add(b, 36)))
      //36 is the offset of the first param of the data, if encoded properly.
      //4 bytes for the function signature, and 32 for the address.
    }
  }

  //txValue is a value at the bottom of the transaction trie.
  function getTransactionDetails(bytes txValue) constant internal returns (Transaction memory tx) {
    RLP.RLPItem[] memory list = txValue.toRLPItem().toList();
    tx.gasPrice = list[1].toUint();
    tx.gasLimit = list[2].toUint();
    tx.to = address(list[3].toUint());
    tx.value = list[4].toUint();
    //Ugly hard coding for now. Can only parse burn transactions.
    tx.data = new bytes(36);
    for (uint i = 0; i < 36; i++) {
      tx.data[i] = txValue[txValue.length - 103 + i];
    }
    return tx;
  }


  //rlpTransaction is a value at the bottom of the transaction trie.
  // function testGetTransactionDetails(bytes rlpTransaction) constant returns (uint, uint, address, bytes) {
  //   Transaction memory tx;
  //   RLP.RLPItem[] memory list = rlpTransaction.toRLPItem().toList();
  //   tx.gasPrice = list[1].toUint();
  //   tx.gasLimit = list[2].toUint();
  //   tx.to = address(list[3].toUint());
  //   tx.value = list[4].toUint();
  //   //Ugly hard coding for now. Can only parse burn transactions.
  //   tx.data = new bytes(36);
  //   for (uint i = 0; i < 36; i++) {
  //     tx.data[i] = rlpTransaction[rlpTransaction.length - 103 + i];
  //   }
  //   return (tx.gasPrice, tx.gasLimit, tx.to, tx.data);
  // }
}
