// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract SmartContract {
    struct Job {
        string title;
        string description;
        string signatureC; //chữ kí của clients
        string signatureF; //chỮ KÍ của Freelancers
        uint256 bids;
        uint256 jobIdcurent;
        uint256 clientId;
        uint256 freelancerId;
        uint8 status;
        //trạng thái status
        //0: đã tạo,1:freelancer đã ký 2:freelancer báo đã hoàn thành,3:client xác nhận(Hợp đồng kết thúc),
        //4:(bị hủy do freelancer),5:(bị hủy do client)
        address client;
        address freelancer;
        string cancelReason; // lí do hủy
    }
    mapping(uint256 => Job) public jobs;
    uint256 public jobId;
    address payable public escrow;

    /*
    + Hàm tạo hợp đồng
       - Chỉ có client mới được tạo
       - Truyền vào thông tin cần thiết( + lưu hình ảnh chữ kí base64,
                                         + lúc này client nạp tiền luôn,
                                         + bids fe không cho nhập mà phải truyền từ job)
       - số ví client sẽ được lưu lại/số ví freelancer để trống
    + Hàm ký hợp đồng
       - validate:Check ví người kí!= ví người tạo,check trạng thái hợp đồng
       - Lưu xuống status
       - chữ kí
    + Hàm hủy dành cho freelancer
       - validate:Check ví ==ví freelancer,check trạng thái hợp đồng(chưa bị hủy và đã được tạo)
       - Lưu xuống lí do hủy, chỉnh lại status
       - Hoàn tiền về cho client
    + Hàm hủy dành cho client
       - validate:Check ví ==ví client,check trạng thái hợp đồng(chưa bị hủy và đã được tạo, chưa được client xác nhận final)
       - Lưu xuống lí do hủy, chỉnh lại status
       - Hoàn tiền về cho freelancer
    + Hàm báo hoàn thành dành cho freelancer
       - validate:Check ví ==ví freelancer,check trạng thái hợp đồng(đã kí)
       - chỉnh lại status
    + Hàm báo kết thúc hợp đồng dành cho client
       - validate:Check ví ==ví client,check trạng thái hợp đồng(đã đc freelancer xác nhận)
       - chỉnh lại status
       - báo hợp đồng thành công
    ================== NHỮNG HÀM READ ====================
    + Lấy thông tin hợp đồng theo JOBID
    + Lấy thông tin tất cả hợp đồng theo ví
    + Lấy tất cả hợp đồng theo JOB
    =======================================================
    */

    constructor() {
        escrow = payable(msg.sender);
    }

    modifier onlyClient(uint256 id) {
        // validate chỉ có client mới thực hiện dc thao tác này
        require(
            msg.sender == jobs[id].client,
            "Only client can call this function"
        );
        _;
    }

    modifier onlyFreelancer(uint256 id) {
        // validate chỉ có freelancer mới thực hiện dc thao tác này
        require(
            msg.sender == jobs[id].freelancer,
            "Only freelancer can call this function"
        );
        _;
    }

    modifier contractNotCanceled(uint256 id) {
        //Valuda nếu hợp đồng đã Hủy thì kh đc hủy
        require(jobs[id].status < 4, "Contract is canceled");
        _;
    }

    modifier contractNotAccepted(uint256 id) {
        // check hợp đồng chấp thuận chưa
        require(jobs[id].status < 1, "Contract is already accepted");
        _;
    }

    function getBalance() public view returns (uint256) {
        //lấy thông tin tiền trong ví trung gian
        return address(escrow).balance;
    }

    event JobCreated(uint256 indexed jobId); // Sự kiện trả về job ID

    function createContract(
        string memory _title,
        string memory _description,
        string memory _signature,
        uint256 _bids,
        uint256 _jobId,
        uint256 _freelancerId,
        uint256 _clientId
    ) external payable returns (uint256) {
        require(msg.value == _bids, "Insufficient amount sent");
        //số  tiền gởi phải bằng với số tiền thầu dự án trong hợp đồng
        emit Ok();
        uint256 balanceBefore = getBalance();
        emit BalanceBefore(balanceBefore);
        jobId++;
        jobs[jobId - 1] = Job({
            title: _title,
            description: _description,
            bids: _bids,
            status: 0,
            signatureC: _signature,
            signatureF: "",
            jobIdcurent: _jobId,
            clientId: _clientId,
            freelancerId: _freelancerId,
            client: msg.sender,
            freelancer: address(0),
            cancelReason: ""
        });
        // Phát sinh sự kiện trả về job ID
        emit JobCreated(jobId - 1);
        // Nạp số tiền vào ví trung gian
        //escrow.transfer(_bids);

        return jobId - 1; //return về id hợp đồng
    }

    //check điều kiện[contract kh bị hủy, contract chưa đc accept
    function acceptContract(uint256 id, string memory signature)
        external
        contractNotCanceled(id)
        contractNotAccepted(id)
    {
        require(
            msg.sender != jobs[id].client,
            "Client can't accept this contract"
        );
        jobs[id].status = 1; // gán giá trị status=1 client chấp thuận
        jobs[id].signatureF = signature;
        jobs[id].freelancer = msg.sender; // Gán địa chỉ của freelancer
    }

    ///kiểm tra giúp tôi hàm bên dưới
    /// write funtion finalizeContract and pay from escrows to freelancer

    // contract hoàn thành chỉ client đc thực hiện
    function finalizeContract(uint256 id) external onlyClient(id) {
        require(jobs[id].status == 2, "Contract is not finalized yet");
        jobs[id].status = 3;

        // Kiểm tra số dư của hợp đồng trước khi chuyển tiền
        //uint256 contractBalance = address(this).balance;
        //require(contractBalance >= jobs[id].bids/1000000000000000000, "Contract balance is insufficient");

        // Chuyển tiền sang tài khoản của freelancer
        // send all Ether to owner
        // (bool success,) = jobs[id].freelancer.call{value: jobs[id].bids}("");
        // require(success, "Failed to send Ether");
        payable(jobs[id].freelancer).transfer(jobs[id].bids);
    }

    function getJobInfoByCurrentJobId(uint256 currentJobId)
        external
        view
        returns (
            uint256,
            string memory,
            string memory,
            string memory,
            string memory,
            uint256,
            uint8,
            address,
            address
        )
    {
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].jobIdcurent == currentJobId && jobs[i].status <= 3) {
                return (
                    i,
                    jobs[i].title,
                    jobs[i].description,
                    jobs[i].signatureF,
                    jobs[i].signatureC,
                    jobs[i].bids,
                    jobs[i].status,
                    jobs[i].client,
                    jobs[i].freelancer
                );
            }
        }
        revert("Job not found or canceled");
    }

    function cancelContract(uint256 id, string memory reason) external {
        require(
            msg.sender == jobs[id].client || msg.sender == jobs[id].freelancer,
            "Only client or freelancer can cancel this contract"
        );

        require(jobs[id].status < 4, "Contract cannot be canceled");

        if (msg.sender == jobs[id].client) {
            // Nếu client hủy hợp đồng
            require(
                jobs[id].status < 3,
                "Contract cannot be canceled by client at this stage"
            );

            jobs[id].status = 5; // Cập nhật trạng thái hủy bởi client
            jobs[id].cancelReason = reason; // Lưu lí do hủy
            payable(jobs[id].freelancer).transfer(jobs[id].bids); // Chuyển tiền về cho freelancer
        } else {
            // Nếu freelancer hủy hợp đồng
            require(
                jobs[id].status < 2,
                "Contract cannot be canceled by freelancer at this stage"
            );

            jobs[id].status = 4; // Cập nhật trạng thái hủy bởi freelancer
            jobs[id].cancelReason = reason; // Lưu lí do hủy
            payable(jobs[id].client).transfer(jobs[id].bids); // Chuyển tiền về cho client
        }
    }

    // freelancer báo hoàn thành
    function reportCompletion(uint256 id) external onlyFreelancer(id) {
        require(jobs[id].status == 1, "Contract is not accepted yet");
        jobs[id].status = 2;
    }

    function getContractsByAddress(address userAddress)
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (
                jobs[i].client == userAddress ||
                jobs[i].freelancer == userAddress
            ) {
                count++;
            }
        }

        uint256[] memory userContracts = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (
                jobs[i].client == userAddress ||
                jobs[i].freelancer == userAddress
            ) {
                userContracts[index] = i;
                index++;
            }
        }
        return userContracts;
    }

    function getContractsByClientId(uint256 clientId)
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].clientId == clientId) {
                count++;
            }
        }

        uint256[] memory clientContracts = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].clientId == clientId) {
                clientContracts[index] = i;
                index++;
            }
        }
        return clientContracts;
    }

    function getContractsByFreelancerId(uint256 freelancerId)
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].freelancerId == freelancerId) {
                count++;
            }
        }

        uint256[] memory freelancerContracts = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].freelancerId == freelancerId) {
                freelancerContracts[index] = i;
                index++;
            }
        }
        return freelancerContracts;
    }

    function getContractsByClientAddress(address clientAddress)
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].client == clientAddress) {
                count++;
            }
        }

        uint256[] memory clientContracts = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].client == clientAddress) {
                clientContracts[index] = i;
                index++;
            }
        }
        return clientContracts;
    }

    function getContractsByFreelancerAddress(address freelancerAddress)
        external
        view
        returns (uint256[] memory)
    {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].freelancer == freelancerAddress) {
                count++;
            }
        }

        uint256[] memory freelancerContracts = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].freelancer == freelancerAddress) {
                freelancerContracts[index] = i;
                index++;
            }
        }
        return freelancerContracts;
    }

    event BalanceBefore(uint256 balance);
    event Ok();
}
