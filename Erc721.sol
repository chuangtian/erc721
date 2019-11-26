pragma solidity 0.5.6;

import "https://github.com/0xcert/ethereum-erc721/src/contracts/tokens/erc721.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/tokens/erc721-token-receiver.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/tokens/erc721-enumerable.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/tokens/erc721-metadata.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/math/safe-math.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/utils/supports-interface.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/utils/address-utils.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/ownership/ownable.sol";


contract Tian is ERC721 , SupportsInterface , ERC721Enumerable , ERC721Metadata, Ownable {
	using SafeMath for uint256;
	using AddressUtils for address;
    /**
     * 可以接收NEFT的智能合约的魔术值。
     * Equal to: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")).
    */
    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;
	
	/**
	 * 从NFT ID到拥有它的地址的映射。保存的ID对应的地址
	*/
	mapping (uint256 => address) internal idToOwner;
	
	/**
	 * 从NFT ID映射到批准的地址。批准的地址可以操作这个ID
	*/
	mapping (uint256 => address) internal idToApproval;
	
	/**
	* 保存地址有多少ID
	*/
	mapping (address => uint256) private ownerToNFTokenCount;
	
	/**
	 * 从所有者地址到操作员地址的映射。记录操作员能不能操作我的ID
	*/
	mapping (address => mapping (address => bool)) internal ownerToOperators;
/*---------------定义ID，授权，ID索引（ID总数）， -------------------*/
	/**
	* 所有token ID的数组。
	*/
	uint256[] internal tokens;

	/**
	* 设置ID到期时间
	*/
	mapping (uint256 => uint256) internal idExpireDate;

	//设置账号，id过期转入此账号自动销毁
	address public burnAddress;

	/**
	 * 从令牌ID映射到全局令牌数组中的索引。
	 */
	mapping(uint256 => uint256) internal idToIndex;

	/**
	 * 从所有者到拥有的NFT ID列表的映射。
	 */
	mapping(address => uint256[]) internal ownerToIds;

	/**
	 *Token ID映射到所有者令牌列表中的索引。
	 */
	mapping(uint256 => uint256) internal idToOwnerIndex;
/*-------------------------*/

	/**
	* 名字
	*/
	string internal nftName;

	/**
	 * 简称
	 */
	string internal nftSymbol;

	/**
	 *  ID映射到元数据uri。
	 */
	mapping (uint256 => string) internal idToUri;


	/*
	*转账事件
	*/
	event Transfer( address indexed _from, address indexed _to, uint256 indexed _tokenId );
	
	/*
	* 授权运营商
	*/
	event ApprovalForAll( address indexed _owner, address indexed _operator, bool _approved );
	
	/*
	* 验证msg.sender是指定ID的所有者或运营商
	*/
	modifier canOperate( uint256 _tokenId ) {
		address tokenOwner = idToOwner[_tokenId];
		require(tokenOwner == msg.sender || ownerToOperators[tokenOwner][msg.sender]);
		_;
	}
	
	/*
	*验证msg.sender是不是可以转移ID。
	*/
	modifier canTransfer( uint256 _tokenId ) {
		address tokenOwner = idToOwner[_tokenId];
		require( tokenOwner == msg.sender || idToApproval[_tokenId] == msg.sender || ownerToOperators[tokenOwner][msg.sender] );
		_;
	}
	/*
	* 验证token是不是有效的
	*/
	modifier validNFToken( uint256 _tokenId ) {
		require(idToOwner[_tokenId] != address(0));
		_;
	}
	
	constructor() public { 
		supportedInterfaces[0x80ac58cd] = true; // ERC721
		supportedInterfaces[0x780e9d63] = true; // ERC721Enumerable
		supportedInterfaces[0x5b5e139f] = true; // ERC721Metadata
		nftName = "Tian Chuang";
		nftSymbol = "TC";
		burnAddress = 0x3138E4972c9ACd112E5514286B76A58442981f0B;
	}

	/**
	* 返回token名字
	* @return Representing name.
	*/
	function name() external view returns (string memory _name) {
		_name = nftName;
	}

	/**
	* 简称
	* @return Representing symbol.
	*/
	function symbol() external view returns (string memory _symbol) {
		_symbol = nftSymbol;
	}

	/**
     * 给定NFT的不同URI（RFC 3986）
     * @param _tokenId Id for which we want uri.
     * @return URI of _tokenId.
     */
	function tokenURI( uint256 _tokenId ) external view validNFToken(_tokenId) returns (string memory) {
		return idToUri[_tokenId];
	}

	/**
	* 为给定的NFT ID设置唯一的URI（RFC 3986）。
	* @notice This is an internal function which should be called from user-implemented external
	* function. Its purpose is to show and properly initialize data structures when using this
	* implementation.
	* @param _tokenId Id for which we want uri.
	* @param _uri String representing RFC 3986 URI.
	*/
	function _setTokenUri( uint256 _tokenId, string memory _uri ) internal validNFToken(_tokenId) {
		idToUri[_tokenId] = _uri;
	}

	//转账函数
	/**
   * 执行转账，只能内部调用。判断_from是否为所有者，_to不能为0x000000000000000000000
   * @param _from The current owner of the NFT.
   * @param _to The new owner.
   * @param _tokenId The NFT to transfer.
   * @param _data Additional data with no specified format, sent in call to `_to`.
   */
	function _safeTransferFrom( address _from, address _to, uint256 _tokenId, bytes memory _data ) private canTransfer(_tokenId) validNFToken(_tokenId) {
		address tokenOwner = idToOwner[_tokenId];
		require(tokenOwner == _from);
		require(_to != address(0));
		_transfer(_to, _tokenId);
		if (_to.isContract())  {
		  bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
		  require(retval == MAGIC_ON_ERC721_RECEIVED);
		}
  }
  
	/**
	* 执行转账。
	* @notice Does NO checks.
	* @param _to Address of a new owner.
	* @param _tokenId The NFT that is being transferred.
	*/
	function _transfer( address _to, uint256 _tokenId ) internal {
		address from = idToOwner[_tokenId];
		_clearApproval(_tokenId);
		_removeNFToken(from, _tokenId);
		_addNFToken(_to, _tokenId);
		emit Transfer(from, _to, _tokenId);
	}


	/**
	* 删除ID的授权地址
	*/
	function _clearApproval(uint256 _tokenId) private {
		if (idToApproval[_tokenId] != address(0)){
			delete idToApproval[_tokenId];
		}
	}
	/**
	* 从所有者中删除id。
	* 请谨慎使用和覆盖此功能。 错误使用会造成严重后果。
	* @param _from Address from wich we want to remove the NFT.
	* @param _tokenId Which NFT we want to remove.
	*/
	function _removeNFToken( address _from, uint256 _tokenId ) internal{
		require(idToOwner[_tokenId] == _from);
		ownerToNFTokenCount[_from] = ownerToNFTokenCount[_from] - 1;
		delete idToOwner[_tokenId];
		//查询ID在所有者中的索引，从所有者中删除ID
		uint index=idToOwnerIndex[_tokenId];
		for (uint i = index; i<ownerToIds[_from].length-1; i++){
			ownerToIds[_from][i] = ownerToIds[_from][i+1];
		}
		delete ownerToIds[_from][ownerToIds[_from].length-1];
		ownerToIds[_from].length--;
	}

	/**
	* 向所有者分配新的ID。
	* 请谨慎使用和覆盖此功能。 错误使用会造成严重后果。
	* @param _to Address to wich we want to add the NFT.
	* @param _tokenId Which NFT we want to add.
	*/
	function _addNFToken( address _to, uint256 _tokenId ) internal {
		require(idToOwner[_tokenId] == address(0));
		idToOwner[_tokenId] = _to;
		ownerToNFTokenCount[_to] = ownerToNFTokenCount[_to].add(1);
		uint256 length = ownerToIds[_to].push(_tokenId);
		idToOwnerIndex[_tokenId] = length - 1;
	}

	/*
	* 转账
	*/
	function safeTransferFrom( address _from, address _to, uint256 _tokenId, bytes calldata _data ) external {
		/*-----------id不设置过期时间-------------*/
		//_safeTransferFrom(_from, _to, _tokenId, _data);
		/*---------------------------------------*/


		/*--------------------id过期_to==burnAddress销毁否则正常转出-----------------------------*/
		//判断id有没有设置过期时间并判断id过期时间，0为未设置。
		if(idExpireDate[_tokenId]==0 ||idExpireDate[_tokenId]>=now){
			_safeTransferFrom(_from, _to, _tokenId, _data);
		}else{
			//id已过期，判断_to的地址等不等于设置的地址
			if(burnAddress!=_to){
				_safeTransferFrom(_from, _to, _tokenId, _data);
			}else{
				//销毁
				_burn(_tokenId);
				if (bytes(idToUri[_tokenId]).length != 0){
					delete idToUri[_tokenId];
				}
			}
		}




	}

	/**
	* 转账 跟上面的功能一样，只不过没有data
	* @param _from The current owner of the NFT.
	* @param _to The new owner.
	* @param _tokenId The NFT to transfer.
	*/
	function safeTransferFrom( address _from, address _to, uint256 _tokenId ) external {
		_safeTransferFrom(_from, _to, _tokenId, "");
	}

	/**
	* 用户自己转账（待测试是不是任何人都可以转）
	* @param _from The current owner of the NFT.
	* @param _to The new owner.
	* @param _tokenId The NFT to transfer.
	*/
	function transferFrom( address _from, address _to, uint256 _tokenId ) external canTransfer(_tokenId) validNFToken(_tokenId) {
		address tokenOwner = idToOwner[_tokenId];
		require(tokenOwner == _from);
		require(_to != address(0));
		_transfer(_to, _tokenId);
	}

	/**
	* 设置或确认NFT的批准地址。 此功能可以更改为应付款. (授权这个地址可以操作这个ID)
	* 零地址表示没有批准的地址。 除非`msg.sender`是当前NFT所有者或当前所有者的授权运营商，否则抛出。
	* @param _approved Address to be approved for the given NFT ID.
	* @param _tokenId ID of the token to be approved.
	*/
	function approve( address _approved, uint256 _tokenId ) external canOperate(_tokenId) validNFToken(_tokenId) {
		address tokenOwner = idToOwner[_tokenId];
		require(_approved != tokenOwner);
		idToApproval[_tokenId] = _approved;
		emit Approval(tokenOwner, _approved, _tokenId);
	}

	/**
	*  启用或禁用对第三方（“操作员”）管理“ msg.sender”所有资产的批准。 它还会发出ApprovalForAll事件。
	* @notice This works even if sender doesn't own any tokens at the time.
	* @param _operator Address to add to the set of authorized operators.
	* @param _approved True if the operators is approved, false to revoke approval.
	*/
	function setApprovalForAll(address _operator,bool _approved) external {
		ownerToOperators[msg.sender][_operator] = _approved;
		emit ApprovalForAll(msg.sender, _operator, _approved);
	}
	/**
	* 返回地址拥有id的数量
	* @param _owner Address for whom to query the balance.
	* @return Balance of _owner.
	*/
	function balanceOf( address _owner ) external view returns (uint256) {
		require(_owner != address(0));
		return _getOwnerNFTCount(_owner);
	}
	/**
	* 计算地址的数量
	* @param _owner Address for whom to query the count.
	* @return Number of _owner NFTs.
	*/
	function _getOwnerNFTCount( address _owner ) internal view returns (uint256) {
		return ownerToNFTokenCount[_owner];
	}

	/**
	* 返回id所有者的地址。 分配给零地址的NFT被认为是无效的，有关它们的查询也会抛出异常。
	* @param _tokenId The identifier for an NFT.
	* @return Address of _tokenId owner.
	*/
	function ownerOf( uint256 _tokenId ) external view returns (address _owner) {
		_owner = idToOwner[_tokenId];
		require(_owner != address(0));
	}

	/**
	* 获取单个id的批准地址。
	* 如果`_tokenId`不是有效的NFT，则抛出该异常
	* @param _tokenId ID of the NFT to query the approval of.
	* @return Address that _tokenId is approved for.
	*/
	function getApproved(uint256 _tokenId) external view validNFToken(_tokenId) returns (address) {
		return idToApproval[_tokenId];
	}

	/**
	*  检查“ _operator”是否是“ _owner”的认可运营商。
	* @param _owner The address that owns the NFTs.
	* @param _operator The address that acts on behalf of the owner.
	* @return True if approved for all, false otherwise.
	*/
	function isApprovedForAll( address _owner, address _operator ) external view returns (bool) {
		return ownerToOperators[_owner][_operator];
	}


	/**
	*  铸造新的token。
	* @notice This is an internal function which should be called from user-implemented external
	* mint function. Its purpose is to show and properly initialize data structures when using this
	* implementation.
	* @param _to The address that will own the minted NFT.
	* @param _tokenId of the NFT to be minted by the msg.sender.
	*/
	function mint( address _to, uint256 _tokenId  , uint256  _expireDate, string calldata _uri ) external {
		require(_to != address(0)); //发送的地址不能等于0x0000000的地址
		require(idToOwner[_tokenId] == address(0));
		_addNFToken(_to, _tokenId);

		/*--------------------------------------------*/
		//设置id时间(另外加的)
		idExpireDate[_tokenId] = _expireDate;
		/*--------------------------------------------*/
		emit Transfer(address(0), _to, _tokenId);

		uint256 length = tokens.push(_tokenId);
		idToIndex[_tokenId] = length - 1;



		_setTokenUri(_tokenId, _uri);
	}

	/**
	*销毁ID
	* @notice This is an internal function which should be called from user-implemented external burn
	* function. Its purpose is to show and properly initialize data structures when using this
	* implementation. Also, note that this burn implementation allows the minter to re-mint a burned
	* NFT.
	* @param _tokenId ID of the NFT to be burned.
	*/
	function _burn( uint256 _tokenId ) internal validNFToken(_tokenId) {
		address tokenOwner = idToOwner[_tokenId];
		_clearApproval(_tokenId);
		_removeNFToken(tokenOwner, _tokenId);
		emit Transfer(tokenOwner, address(0), _tokenId);

		uint256 tokenIndex = idToIndex[_tokenId];
		uint256 lastTokenIndex = tokens.length - 1;
		uint256 lastToken = tokens[lastTokenIndex];

		tokens[tokenIndex] = lastToken;

		tokens.length--;
		// This wastes gas if you are burning the last token but saves a little gas if you are not.
		idToIndex[lastToken] = tokenIndex;
		idToIndex[_tokenId] = 0;

		//删除uri
		if (bytes(idToUri[_tokenId]).length != 0)
		{
			delete idToUri[_tokenId];
		}
	}

	/**
	* 返回所有现有NFToken的计数。
	* @return Total supply of NFTs.
	*/
	function totalSupply() external view returns (uint256) {
		return tokens.length;
	}

	/**
	* 通过其索引返回NFT ID。
	* @param _index A counter less than `totalSupply()`.
	* @return Token id.
	*/
	function tokenByIndex( uint256 _index ) external view returns (uint256) {
		require(_index < tokens.length);
		return tokens[_index];
	}

	/**
	* 从所有者令牌列表中返回第n个NFT ID。
	* @param _owner Token owner's address.
	* @param _index Index number representing n-th token in owner's list of tokens.
	* @return Token id.
	*/
	function tokenOfOwnerByIndex( address _owner, uint256 _index ) external view returns (uint256) {
		require(_index < ownerToIds[_owner].length);
		return ownerToIds[_owner][_index];
	}

//	/*
//	*删除token
//	*/
//	function removeNFToken( address _from, uint256 _tokenId ) external {
//		require(idToOwner[_tokenId] == _from);
//		delete idToOwner[_tokenId];
//
//		uint256 tokenToRemoveIndex = idToOwnerIndex[_tokenId];
//		uint256 lastTokenIndex = ownerToIds[_from].length - 1;
//
//		if (lastTokenIndex != tokenToRemoveIndex)
//		{
//			uint256 lastToken = ownerToIds[_from][lastTokenIndex];
//			ownerToIds[_from][tokenToRemoveIndex] = lastToken;
//			idToOwnerIndex[lastToken] = tokenToRemoveIndex;
//		}
//
//		ownerToIds[_from].length--;
//		tokens.length--;
//	}


	/**
	* 获取说所有者的ID总数
	* extension to remove double storage(gas optimization) of owner nft count.
	* @param _owner Address for whom to query the count.
	* @return Number of _owner NFTs.
	*/
	function getOwnerNFTCount( address _owner ) public view returns (uint256) {
		return ownerToIds[_owner].length;
	}

	//销毁
	function burn( uint256 _tokenId ) external {
		_burn(_tokenId);
		if (bytes(idToUri[_tokenId]).length != 0){
			delete idToUri[_tokenId];
		}
	}



}