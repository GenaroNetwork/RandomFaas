pragma solidity>=0.4.20;

/*
   The random faas provide the interface that smooths the random function 
   and make it simpler for users to call 
   Author : waylon(waylon@genaro.network)
  
 */

contract RandomFaas {

	address payable public owner;

	uint public counts;
	uint public limit;
	uint countdown; //in block
	address[] depositAdderesses;

	struct Req {
		uint randomNum;
		bytes32 signature;	
		uint value;
	}
	
	struct Option {
		bool NoQuitFlag;
		uint CloseTime; //in block 
		
	}
	

	mapping (uint => mapping (address => Req[])) public RandomGroup;
	mapping (uint => address[]) public GroupList;
	mapping (uint => Option) public GroupOption;
	

	event quitActor(address victim);
	event startCountin(address group, uint startTime);
	event NeedNewGroup(uint counts);
	event randomOutput(address group, uint randomNumber);

    constructor (address payable _owner, uint _countdown, uint _limit) public 
	{
		require(_owner != address(0));
		require(_countdown != 0);
		require(_limit != 0);

		owner = _owner;
		countdown = _countdown;
		limit = _limit;
	}
	
	//deposit
	function () external payable {
		deposit();
	}

	function deposit () public payable {
		require(msg.value>0);
		depositAdderesses[depositAdderesses.length]=msg.sender;
	}
	
	function withdraw () public 
	only(owner)
	{
		require(owner.send(address(this).balance));	
	}
	
	
	function createGroup () public
	{
		updateValue(RandomGroup[counts][msg.sender],0,0,0);
		counts++;
	}

	
	function stakeJoin () public payable
	{
		require(GroupList[counts].length<limit);
		emit NeedNewGroup(counts);
		
		updateValue(RandomGroup[counts][msg.sender],0,bytes32(0),msg.value);
		GroupList[counts].push(msg.sender);

	}
	
	function updateValue (Req[] storage group, uint _randomNum, bytes32 _signature,uint _value) 
	internal
	{
		uint _ptr = group.length;

		Req storage newMember = group[group.length++];
        Req storage oldMember = group[_ptr];
	    
		newMember.randomNum = oldMember.randomNum>_randomNum?oldMember.randomNum:_randomNum;

        if(_signature[0] != 0){
			newMember.signature = _signature;
	    }else{
			newMember.signature = oldMember.signature;
		}


	    newMember.value = oldMember.value> _value?oldMember.value:_value;

	}
	
	function commitRandom (uint _randomNum, uint _count) public
	{
		require(_count<counts);
		require(_randomNum != 0);
        
	    updateValue(RandomGroup[_count][msg.sender],_randomNum,bytes32(0),0);

	}

	function commitSignRandom (bytes32 _message, bytes memory _signature, uint _count) public
	{  
		Req storage latestInfo = RandomGroup[_count][msg.sender][RandomGroup[_count][msg.sender].length];
		require(latestInfo.signature[0] == 0);
        require(recover(_message,_signature)==msg.sender);
	
 	    updateValue(RandomGroup[_count][msg.sender],0,_message,0);	
		GroupOption[_count].NoQuitFlag = true;
		GroupOption[_count].CloseTime = block.number+countdown;

	}
	
//from open-zepplin EC-Recovery
  /**
   * @dev Recover signer address from a message by using their signature
   * @param _hash bytes32 message, the hash is the signed message. What is recovered is the signer address.
   * @param _sig bytes signature, the signature is generated using web3.eth.sign()
   */
  function recover(bytes32 _hash, bytes memory _sig)
    internal
    pure
    returns (address)
  {
    bytes32 r;
    bytes32 s;
    uint8 v;

    // Check the signature length
    if (_sig.length != 65) {
      return (address(0));
    }

    // Divide the signature in r, s and v variables
    // ecrecover takes the signature parameters, and the only way to get them
    // currently is to use assembly.
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      r := mload(add(_sig, 32))
      s := mload(add(_sig, 64))
      v := byte(0, mload(add(_sig, 96)))
    }

    // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
    if (v < 27) {
      v += 27;
    }

    // If the version is correct return the signer address
    if (v != 27 && v != 28) {
      return (address(0));
    } else {
      // solium-disable-next-line arg-overflow
      return ecrecover(_hash, v, r, s);
    }
  }

  /**
   * toEthSignedMessageHash
   * @dev prefix a bytes32 value with "\x19Ethereum Signed Message:"
   * and hash the result
   */
  function toEthSignedMessageHash(bytes32 _hash)
    internal
    pure
    returns (bytes32)
  {
    // 32 is the length in bytes of hash,
    // enforced by the type signature above
    return keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)
    );
  }

 	function closeProcess (uint _count) public  returns (bytes32 _result)
 	{
		require(RandomGroup[_count][msg.sender][RandomGroup[_count][msg.sender].length].randomNum != 0);
		require(RandomGroup[_count][msg.sender][RandomGroup[_count][msg.sender].length].signature[0] != 0);
		
		address _addr;
		//to do: in certain time should not do closeProcess
		if (block.number >= GroupOption[_count].CloseTime){

			//calculate the random result
			for (uint cnt = 0; cnt < GroupList[_count].length; cnt++){
				_addr = GroupList[_count][cnt];
				_result = _result ^ RandomGroup[_count][_addr][RandomGroup[_count][msg.sender].length].signature;
			}			
		}

	}
	

	function punishQuitter (uint _count) public {
		
		uint _punish;
		address _addr;
		uint _payback;
		
		address[10] memory _bounter;
		uint counter;

		for(uint cnt=0; cnt< GroupList[_count].length;cnt++){
			_addr = GroupList[_count][cnt];
			if(RandomGroup[_count][_addr][RandomGroup[_count][msg.sender].length].randomNum == 0 || RandomGroup[_count][_addr][RandomGroup[_count][msg.sender].length].signature[0] == 0){
				_punish += RandomGroup[_count][_addr][RandomGroup[_count][msg.sender].length].value;
			}else{
				_bounter[counter++]=_addr;
			}
		}

		_payback =safeDiv(_punish,_bounter.length);

		for(uint cnt=0;cnt<_bounter.length;cnt++){
			_addr = _bounter[cnt];
			_addr.call.value(_payback).gas(2300); //no sure about the result, need to check
			//_addr.transfer(_payback); //why it can not work?!
		}
	}
	
	function cancelProcess (uint _count) public{	

		require(GroupOption[_count].NoQuitFlag == false);

		address _addr;
		uint _reimbursement;
		// return all the money back.
		for(uint cnt = 0; cnt <GroupList[_count].length;cnt++){
			_addr = GroupList[_count][cnt];
			_reimbursement = RandomGroup[_count][_addr][RandomGroup[_count][msg.sender].length].value;

			if(_reimbursement != 0){
				_addr.call.value(_reimbursement).gas(2300); //same here
			 	//_addr.send(_reimbursement);
			}
		}
		
	}
	
	modifier only(address _addr) { 
		require(msg.sender == _addr);
		_; 
	}


  function safeDiv(uint a, uint b) internal returns (uint) {
    assert(b > 0);
    uint c = a / b;
    assert(a == b * c + a % b);
    return c;
  }	


}
