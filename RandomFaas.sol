pragma solidity ^0.4.13;

/**
 * The random faas provide the interface that smooths the random function 
 * and make it simpler for users to call 
 * Author : waylon(waylon@genaro.network)
 */
contract RandomFaas {

	address public owner;

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

	function RandomFaas (address _owner, uint _countdown, uint _limit) 
	{
		require(_owner != address(0));
		require(_counttime != 0);
		require(_limit != 0);

		owner = _owner;
		countdown = _countdown;
		limit = _limit;
	}
	
	//deposit
	function () public payable {
		deposit();
	}

	function deposit () public payable {
		require(msg.value>0);
		depositAdderesses[depositAdderesses.length]=msg.sender;
	}
	
	function withdraw () public 
	only(owner)
	{
		require(owner.send(this.balance));	
	}
	
	
	function createGroup (address _operator) public
	{
		require(_operator != address(0));
		Req[] storage group = RandomGroup[counts][msg.sender];
		address[] storage list = GroupList[counts];
		counts++;
	}

	
	function stakeJoin () public payable
	{
		require(_operator != address(0));
		require(GroupList[counts].length<limit);
		NeedNewGroup(counts);
		
		updateValue(RandomGroup[counts][msg.sender],0,0,msg.value);
		GroupList[counts].push(msg.sender);

	}
	
	function updateValue (Req[] storage group, uint _randomNum, uint _signature) 
	internal
	{
		uint _ptr = group.length;

		Req storage newMember = group[group.length++];
		newMember.randomNum = _randomNum;
		newMember.signature = _signature;


	}
	
	function commitRandom (uint _randomNum, uint _count) public
	{

		require(_randomNum != 0);
		RandomGroup[_count][msg.sender].randomNum = _randomNum;

	}

	function commitSignRandom (bytes32 _sign, uint _count) public
	{
		require(RandomGroup[_count][msg.sender].signature == bytes32(0));
		require(sha3(RandomGroup[_count][msg.sender].randomNum,msg.sender) == _sign);
		RandomGroup[_count][msg.sender].signature = _sign;
		GroupOption[_count].NoQuitFlag = true;
		GroupOption[_count].CloseTime = block.number+countdown;

	}
	
 	function closeProcess (uint _count) returns (bytes32 _result) public
 	{
		require(RandomGroup[_count][msg.sender].randomNum != 0);
		require(RandomGroup[_count][msg.sender].signature != bytes32(0));
		
		address _addr;
		//to do: in certain time should not do closeProcess
		if (block.number >= GroupOption[_count].CloseTime){

			//calculate the random result
			for (uint cnt = 0; cnt < GroupList[_count].length; cnt++){
				_addr = GroupList[_count][cnt];
				_result = _result ^ RandomGroup[_count][_addr];
			}			
		}

	}
	

	function punishQuitter (uint _count) public {
		
		uint _punish;
		address _addr;
		address[] _bounter;
		uint _payback;

		for(uint cnt=0; cnt< GroupList[_count].length;cnt++){
			_addr = RandomGroup[_count][cnt];
			if(RandomGroup[_count][_addr].randomNum == 0 || RandomGroup[_count][_addr].signature = bytes32(0)){
				_punish += RandomGroup[_count][_addr].value;
			}else{
				_bounter.push(_addr)
			}
		}

		_payback =safeDiv(_punish,_bounter.length);

		for(uint cnt=0;cnt<_bounter.length;cnt++){
			_addr = _bounter[cnt];
			_addr.send(_payback);
		}
	}
	
	function cancelProcess (uint _count) public{	

		require(GroupOption[_count].NoQuitFlag == false);

		address _addr;
		uint _reimbursement;
		// return all the money back.
		for(uint cnt = 0; cnt <GroupList[_count].length;cnt++){
			_addr = GroupList[_count][cnt];
			_reimbursement = RandomGroup[_count][_addr].value;

			if(_reimbursement != 0){
			 	_addr.send(_reimbursement);
			}
		}
		
	}
	
	modifier only(address _addr) { 
		require(msg.sender = _addr)
		_; 
	}


  function safeDiv(uint a, uint b) internal returns (uint) {
    assert(b > 0);
    uint c = a / b;
    assert(a == b * c + a % b);
    return c;
  }	


}
