function varargout = PETwin_acquisition(varargin)
% March 18, 2017 Y.D. Sinelnikov
% yegor@synchropet.com

global DataStream DataSource;

DEBUG=0;

%% Init
out = {};
% if no input argument, goto help
if nargin==0; command = 'help'; else command = lower(varargin{1}); end


%% Switch on commands
switch command
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% read data from network
    case 'open_high_speed_udp'
        if nargin~=2, disp('Open high speed UDP requires buffer size'); return; end
        buffer_size = double(varargin{2});
        hs_port_num = 32003;

        tmp = instrfind('type','udp','localport',hs_port_num);
        if ~isempty(tmp),
            try fclose(tmp); catch, disp('Error closing high speed port'), end
            try delete(tmp); catch, disp('Error deleting high speed port'), end
        end
        
        % clean_up_network_conn();
        DataSource = udp('192.168.120.1',...
            'localport', hs_port_num,...
            'ByteOrder', 'bigEndian',...
            'Timeout',0,...
            'Terminator','',...
            'DatagramTerminateMode','off',...
            'InputBufferSize', buffer_size);
        fopen(DataSource);
        flushinput(DataSource);
        flushoutput(DataSource);
        out = DataSource;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% read data from network using Java inteface
    case 'open_high_speed_udp_java'
        if nargin~=2, disp('Open high speed UDP requires buffer size'); return; end
        word22read = 2*double(varargin{2});
        hs_port_num = 32003;
        
        %%
        % initialize java
        import java.io.*
        import java.net.DatagramSocket
        import java.net.DatagramPacket
        import java.net.InetAddress
        
        tmp = instrfind('type','udp','localport',hs_port_num);
        if ~isempty(tmp),
            try fclose(tmp); catch, disp('Error closing high speed port'), end
            try delete(tmp); catch, disp('Error deleting high speed port'), end
        end
        try DataSource.close; catch, disp('Warining: cannot close Java socket'), end
        
        % DataSource stands for socket
        DataSource = DatagramSocket(hs_port_num);
        DataSource.setSoTimeout(1000);
        DataSource.setReuseAddress(1);
        
        
        out = DataSource;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% read date from network
    case 'acquire_udp'
        if nargin~=2, disp('Acquire UDP requires a number of words to read'); return; end
        DataLength=0;
        Words2Read = double(varargin{2});
        wcnt = 0;
        while wcnt<Words2Read
            if DataSource.BytesAvailable>=520
                if DEBUG, disp(sprintf('%d Before acq bytes available: %d words requested: %d',wcnt,DataSource.BytesAvailable/2,Words2Read)), end
                if DEBUG, tic; end
                [DataRead, DataLength] = fread(DataSource,Words2Read,'uint16');
                DataStream( (wcnt+1):(wcnt+DataLength) ) = DataRead;
                wcnt= wcnt+DataLength;
                if DEBUG, disp(sprintf('Acq from network took %5.3f s to read %d elements out of %d requested',toc,DataLength,Words2Read)); end
                if DEBUG, disp(sprintf('After acq bytes available: %d',DataSource.BytesAvailable)), end
            else
                break;
            end
        end
        out = wcnt;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% read data from network
    case 'acquire_udp_java'
        if nargin~=2, disp('Acquire UDP requires a number of words to read'); return; end
        
        %%
        % initialize java
        import java.io.*
        import java.net.DatagramSocket
        import java.net.DatagramPacket
        import java.net.InetAddress
        
        DataLength=0;
        Bytes2Read = 2*double(varargin{2});
        bytecount = 0; emptysocketcnt = 0; byteoffset = 0;
        JavaPacket = DatagramPacket(zeros(1,1040,'int8'),1040);

        while bytecount<Bytes2Read
            DataSource.receive(JavaPacket);
            mssg = JavaPacket.getData;
            bcnt = JavaPacket.getLength;
            if bcnt>0
                DataStream( (byteoffset+1):(bcnt+byteoffset) ) = mssg(1:bcnt);
                
                bytecount = bytecount + bcnt;
                byteoffset = byteoffset + bcnt;
            else
                emptysocketcnt=emptysocketcnt+1;
                if emptysocketcnt>32, break, end
            end
        end
        out = bytecount/2;
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% adjust network reading speed
    case 'adjust_udp_speed'
        if nargin~=6, disp('Adjust UDP speed requires 6 arguments'); return; end
        p2r = double(varargin{2});
        udpbuffill = double(varargin{3}); % network buffer status in range 0 to 1
        du_int = double(varargin{4});
        BufferSizeInPackets = double(varargin{5});
        PacketSizeInWords = double(varargin{6});
        
        %%
        % PID controller: Proportional, Integral, Differential constants
        PID = [50 -10 0];
        INTEGRAL_AVERAGES = 100;

        du = udpbuffill-0.5; % difference with 0.5 which is half of the buffer
        du_int = ((INTEGRAL_AVERAGES-1)*du_int + du)/INTEGRAL_AVERAGES; % integral part
        p2r = p2r + round(du*PID(1) + du_int*PID(2));
        
        if p2r<1, p2r=1; end 
        if p2r>BufferSizeInPackets, p2r = BufferSizeInPackets; end
        
        w2r = p2r*PacketSizeInWords;
        
        out{1}=p2r;
        out{2}=w2r;
        out{3}=du_int;
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% read data from file
    case 'acquire_file'
        if nargin~=3, disp('Acquire file requires a number of words to read and machine format'); return; end
        DataLength=0;
        Words2Read = int32(varargin{2});
        MachineFormat = char(varargin{3});
        
        if DEBUG, tic; end
       
        [DataStream, DataLength] = fread(DataSource, Words2Read,'uint16=>uint16',MachineFormat);
        if DEBUG, disp(sprintf('Acquisition from file took %4.1f s',toc)); end
        
        out = DataLength;
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% swap packet headers inplace
    case 'swap_packet_headers_inplace'
        if nargin~=2, disp('Swap requires data length'); return; end
        DataLength = int32(varargin{2});
        Nsplit = 0;
        
        if DEBUG, tic; end
        [pix, qix] = find_packets(DataStream(1:DataLength)); % get packet starts
        if DEBUG, disp(sprintf('New find packets took %4.1f s',toc)); end
        npix = length(pix);
        nqix = length(qix);
        
        % index to all elements containing packet headers
        prix = reshape( ones(8,1)*pix + (0:7)'*ones(size(pix)), 1, [] );
        pall  = DataStream(prix); % save all headers
        
        % all 1:length(prix) elements will be replaced with packet headers
        % so find lagest element in packet header index that will be replaced
        prix_max_ix = max(find(prix<=length(prix)));
        % index to all singles in the beggining of the steam that need to relocated
        if isempty(prix_max_ix)
            srix = 1:length(prix); % all these are singles that need to be copied
        else
            srix = setxor(1:length(prix),prix(1:prix_max_ix));
        end
        % there should be lesss singles that headers replacing them in the
        % beggining of the file, just because some of the space is occupied by
        % headers themselves, so there will be always less sigles to copy than
        % total number of headers. As we copy all headers their number does not
        % matter
        if length(srix)>length(prix)
            disp('Error: wrong packet extraction logic or else');
            return
        end
        
        % copy all singles from srix from the beggining of the stream inplace of
        % packet headers starting from the end that will not be overwritten by next
        % operation
        DataStream(prix(end-length(srix)+1:end)) = DataStream(srix);
        
        % finaly copy all presaved packet headers to the beggining
        DataStream(1:length(prix)) = pall;
        
        % lets double check

        if DEBUG, tic; end
        [pix, qix] = find_packets(DataStream(1:DataLength)); % get packet starts
        if DEBUG, disp(sprintf('New find packets took %4.1f s',toc)); end
        npix2 = length(pix);
        nqix2 = length(qix);
        
        if npix2~=npix | nqix2~=nqix | (pix(end)-1)/8+1~=npix,
            disp('Error: something wrong with packets header swaping')
            return
        end
        
        Nsplit = npix*8;
        out = Nsplit;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%  Extract packet headers and events
    case 'extract_packet_and_events'
        if nargin~=4, disp('Extract packets requires 3 arguments'); return; end
        Nsplit = int32(varargin{2});
        DataLength = int32(varargin{3});
        SortFlag = int32(varargin{4});
        
        % [psn, era] = extract_packet_headers(DataStream(1:Nsplit));
        psn = uint32(DataStream(2:8:Nsplit-6)) + bitshift( uint32(DataStream(1:8:Nsplit-7)),16 );
        era = uint32(DataStream(8:8:Nsplit)) + bitshift( uint32(mod(DataStream(7:8:Nsplit-1),2^12)),16 );
        
        % [etime, easic, echan] = extract_events(DataStream(Nsplit+1:DataLength));
        % Tf = uint32(DataStream(Nsplit+1:4:end-3))+bitshift(uint32(DataStream(Nsplit+2:4:end-2)),16);
        % Tc = uint32(mod(DataStream(Nsplit+3:4:end-1),2^14));
        % etime=int64(bitor(uint64(Tf),bitshift(uint64(Tc),32))); % in clock units
        % etime=int64(bitshift(bitor(uint64(Tf),bitshift(uint64(Tc),32)),1)); % in ns units
        etime=int64(bitshift(bitor(uint64(uint32(DataStream(Nsplit+1:4:DataLength-3))+...
            bitshift(uint32(DataStream(Nsplit+2:4:DataLength-2)),16)),...
            bitshift(uint64(uint32(mod(DataStream(Nsplit+3:4:DataLength-1),2^14))),32)),1)); % in ns units
        
        % HighBits = bitshift(uint32(DataStream(Nsplit+3:4:end-1)),-14) + ...
        %     bitshift(uint32(DataStream(Nsplit+4:4:end)),2);
        % ev.counter=uint32(mod(HighBits,2^6));
        % ev.gate=uint32(mod(bitshift(HighBits,-16),2^2));
        TenBits=uint32(mod(bitshift(bitshift(uint32(DataStream(Nsplit+3:4:DataLength-1)),-14) + ...
            bitshift(uint32(DataStream(Nsplit+4:4:DataLength)),2),-6),2^10));
%         TenBits=uint32(mod(bitshift(uint32(DataStream(Nsplit+4:4:DataLength)),-4),2^10));
        
        easic=int8(bitshift(TenBits,-5));
        echan=int8(mod(TenBits,2^5));
        
        if SortFlag
            [etime, sort_index] = sort(etime);
            easic=easic(sort_index);
            echan=echan(sort_index);
        end
        
        out{1} = sort(psn);
        out{2} = era;
        out{3} = etime;
        out{4} = easic;
        out{5} = echan;
end

%% End
for k=1:nargout
    if iscell(out)
        varargout{k} = out{k};  % return values only if asked
    else
        varargout{k} = out(k);
    end
end

%%
% find indexes of packets with events
function [pix, qix] = find_packets(x)

xx=reshape(x,8,[]);
% find columns with elements 3,4,5,6 zeros
% ixs = find(sum(xx(3:6,:),1)==0); ns = length(ixs);
ixa = find(any(xx(3:6,:),1)==0); na = length(ixa);
% nas = min([ns, na]);
% nni = min(find(ixs(1:nas)-ixa(1:nas))); % this should be empty
% [xx(:,ixs(nni)),xx(:,ixa(nni))]
% [sum(xx(3:6,ixs(nni))),all(xx(3:6,ixa(nni)))]
pix = sub2ind(size(xx),ones(size(ixa)),ixa);
qix = [diff(pix), length(x)-pix(end)+1];
