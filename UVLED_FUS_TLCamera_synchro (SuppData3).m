% Simple Matlab sample for using TSICamera DotNET interface with polling-
% based image acquisition. If the camera is color, returns Bayer-patterned
% mono color images.

clear
close all

sound(sin(1:300));
% Connect the NI Daq board
% daqlist               % Show all the Daq units connected to this computer
dq = daq("ni");
dq.Rate = 10000;        % Daq board scanning frequency
addoutput(dq, "Dev1", "ao0", "Voltage");    % Define the analogue output
addoutput(dq, "Dev1", "ao1", "Voltage");    % Define the analogue output
% Channel 0 is for LED and channel 1 is for FUS

% Definition of imaging paramters
exposure_time = 49.966;         % in ms
camera_gain = 0;            % in dB/10
charging_duration = 5;     % in s
acqusition_interval = 2;    % Time interval between end of charging and image acquisition; in s
trace_interval = 3+2.5;           % The interval between sequential traces, in s
bining_factor = 4;          % Bin the image to reduce the data size
desired_width = 1440/bining_factor;
desired_height = 1080/bining_factor;
NoCycle = 1;

FUS_time = 2;               % The interval between camera trace starts and the FUS pulse
FUS_frame = floor(FUS_time/exposure_time*1000); % The frame index to turn on FUS pulse

fname_pre = 'dark_';

% Load TLCamera DotNet assembly. The assembly .dll is assumed to be in the 
% same folder as the scripts.
NET.addAssembly([pwd, '\Thorlabs.TSI.TLCamera.dll']);
disp('Dot NET assembly loaded.');

tlCameraSDK = Thorlabs.TSI.TLCamera.TLCameraSDK.OpenTLCameraSDK;

% Get serial numbers of connected TLCameras.
serialNumbers = tlCameraSDK.DiscoverAvailableCameras;
disp([num2str(serialNumbers.Count), ' camera was discovered.']);

if (serialNumbers.Count > 0)
    % Open the first TLCamera using the serial number.
    disp('Opening the first camera')
    tlCamera = tlCameraSDK.OpenCamera(serialNumbers.Item(0), false);
    
    % Set exposure time and gain of the camera.
    tlCamera.ExposureTime_us = exposure_time * 1000;
    
    % Check if the camera supports setting "Gain"
    gainRange = tlCamera.GainRange;
    if (gainRange.Maximum > 0)
        tlCamera.Gain = camera_gain;
    end
    
    % Set the bining factor of the camera
    tlCamera.ROIAndBin.BinX = uint8(bining_factor);
    tlCamera.ROIAndBin.BinY = uint8(bining_factor);
    
    % Set the FIFO frame buffer size. Default size is 1.
    tlCamera.MaximumNumberOfFramesToQueue = 5;
    
    % Start continuous image acquisition
    disp('Starting continuous image acquisition.');
    tlCamera.OperationMode = Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;
    tlCamera.FramesPerTrigger_zeroForUnlimited = 0;
    
    for ii = 1:1:NoCycle
        write(dq, [5,0]);   % Turn on the LED to charge
        pause(charging_duration);
        write(dq, [0,0]);   % Turn off the LED
        pause(acqusition_interval);
        
        % Start image aquisition
        tlCamera.Arm;
        tlCamera.IssueSoftwareTrigger;

        numberOfFramesToAcquire = 150;  % acquire for 150 frames (7.5 s)
        frameCount = 0;
        image_stack = zeros(desired_width, desired_height, numberOfFramesToAcquire);

        while frameCount < numberOfFramesToAcquire
            % Check if image buffer has been filled
            if (tlCamera.NumberOfQueuedFrames > 0)

                % If data processing in Matlab falls behind camera image
                % acquisition, the FIFO image frame buffer could overflow,
                % which would result in missed frames.
                if (tlCamera.NumberOfQueuedFrames > 1)
                    disp(['Data processing falling behind acquisition. ' num2str(tlCamera.NumberOfQueuedFrames) ' remains']);
                end

                % If have already aquired 2-s, turn on the FUS pulse
                if frameCount == FUS_frame
                    write(dq, [0, 5]);
                end

                % Get the pending image frame.
                imageFrame = tlCamera.GetPendingFrameOrNull;
                if ~isempty(imageFrame)
                    frameCount = frameCount + 1;

                    % Get the image data as 1D uint16 array
                    imageData = uint16(imageFrame.ImageData.ImageData_monoOrBGR);

                    disp(['Image frame number: ' num2str(imageFrame.FrameNumber)]);

                    % TODO: custom image processing code goes here
                    imageHeight = imageFrame.ImageData.Height_pixels;
                    imageWidth = imageFrame.ImageData.Width_pixels;
                    imageData2D = reshape(imageData, [imageWidth, imageHeight]);
                    image_stack(:,:,frameCount) = imageData2D;
                end

                % Release the image frame
                delete(imageFrame);
            end
        end
        
        % Stop continuous image acquisition
        disp('Stopping continuous image acquisition.');
        tlCamera.Disarm;
                    
        % Reset the DQ board output
        write(dq, [0, 5]);
        
        image_stack = uint16(image_stack);
        % Write the tiff file to save the data
        fname = append(fname_pre, num2str(1), '.tif');
%         fname = append(fname_pre, num2str(ii+720), '.tif');
        t = Tiff(fname,'w');
        tagstruct.ImageLength = desired_width;
        tagstruct.ImageWidth = desired_height;
        tagstruct.SampleFormat = 1; % uint
        tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
        tagstruct.BitsPerSample = 16;
        tagstruct.SamplesPerPixel = 1;
        tagstruct.Compression = Tiff.Compression.None;
        tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
        for jj=1:1:numberOfFramesToAcquire
            setTag(t,tagstruct);
            write(t,image_stack(:,:,jj));
            writeDirectory(t);
        end
        close(t)
                
        % Pause for the interval between sequential traces
        pause(trace_interval)
    end
    
    % Release the TLCamera
    disp('Releasing the camera');
    tlCamera.Dispose;
    delete(tlCamera);
end

% Release the serial numbers
delete(serialNumbers);

% Release the TLCameraSDK.
tlCameraSDK.Dispose;
delete(tlCameraSDK);
