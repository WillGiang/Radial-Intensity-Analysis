// Get the file that you want to process (must be a single slice, single frame, multi-channel image).
#@ File (label="Choose directory with images to process (multi-channel is ok, but must be 1z and 1t)", style = "directory") dir_input
#@ File (label="Choose directory for creating result folders (one level above input data dir?)", style = "directory") dir_main
#@ Integer (label="Number of concentric rings", value = 256) N_rings
#@ Boolean (label="Check box if you want radial color coding", value=true) want_color_coding
#@ String (label="LUT for color coding", choices={"Fire", "Spectrum", "Ice"}, style="listBox") lut_for_color_coding

// Fiji settings
setOption("BlackBackground", true);
run("Set Measurements...", "area mean standard min integrated area_fraction stack display nan redirect=None decimal=3");

n_slices = N_rings - 1;


// Create directories to save: 
// - ROIs
// - colorcoded images to show ROIs
// - intensity meaasurements in CSV files
// - cropped images to show spacing of circles

dir_rois         = dir_main + File.separator + "ROIs"                  + File.separator;
dir_color_coded  = dir_main + File.separator + "ColorCoded"            + File.separator;
dir_measurements = dir_main + File.separator + "IntensityMeasurements" + File.separator;
dir_cropped      = dir_main + File.separator + "Cropped"               + File.separator;


File.makeDirectory(dir_rois);
File.makeDirectory(dir_color_coded);
File.makeDirectory(dir_measurements);
File.makeDirectory(dir_cropped);


// I recommend just using one tif in a folder at a time until you get comfortable with the code.
// It takes a few minutes to run each cell, and you want to make sure it's doing what you think it is.
// That said, this should allow it to process as many tiffs as are in a folder.
// If processing lots of tifs, you might want to consider turning off the bit that makes the hyperstacks and doing more steps in set batch mode hide

list = getFileList(dir_input);

for (i = 0; i< list.length; i++) {
	filename = list[i];
	
	if (endsWith(filename, ".tif")) {
		NucToPM(dir_input, filename);
	}
}
function buildConcatenateStringFromC(N_channels, prefix) {
	// Create the command string for Concatenate for multiple channels
	cmd_concat = "open";
	for (i = 1; i <= N_channels; i++) {
		str_concat = "image" + i + "=" + prefix + i;
		cmd_concat = cmd_concat + " " + str_concat;
		}
	
	return cmd_concat;
}

function NucToPM(dir_input, filename){
	//  Open the file, save info for later, and make a working copy
	run("Bio-Formats", "open=" + dir_input + File.separator + filename + " autoscale color_mode=Default view=Hyperstack stack_order=XYCZT");

	filebase = File.nameWithoutExtension;
	image_orig_name = getTitle();
	getDimensions(_, _, N_channels, _, _);
	
	// TODO: Make the macro work on single channel images?
	run("Split Channels");
	
	// --------------------------------------------------------------------------------------------------------------------

	setBatchMode("hide");
	for(channel = 1; channel <= N_channels; channel++){
		C_str = "C" + channel;
		selectWindow(C_str + "-" + image_orig_name);
		
		for (i=0; i < n_slices; i++){
			run("Duplicate...", "title=&C_str");
			rename(C_str);
		}
		run("Images to Stack", "name=&C_str title=&C_str use");
		rename(C_str);
	}
	
	setBatchMode("exit and display");
// -----------------------------------------------------------------------------------------

	// THE SINGLE MOST IMPORTANT THING IS THAT THERE CAN'T BE ANYTHING IN THE ROI MANAGER WHEN YOU START THIS CODE OR IT WILL BE ERRONEOUSLY INCORPORATED INTO THE INTERPOLATION.
	roiManager("reset");

	// Now we manually select the nucleus and the plasma membrane. Be sure to only hit ok after you have fully traced the structure.  Also make sure not to change the frame once you start.
	// This should be done on the ER channel or whatever channel easily lets you see the nucleus and PM. 
	// The objective here is to create an ROI of the nucleus on slice 1 and an ROI of the plasma membrane on slice 256 then interpolate between them	
	
	waitForUser ( "SelectImage", "Select the image to trace the nucleus and plasma membrane");
	Stack.setSlice(1);			
	setTool("polygon"); // Do your best to trace the nucleus. Don't worry about sharp angles; this runs a fit spline command to make your annotation nice and SMOOOOOTH
	waitForUser ( "Nucleus", "Trace the Nucleus");
	run("Fit Spline");
	roiManager("Add");
	run("Select None");	
	Stack.setSlice(N_rings);
	waitForUser ( "ROI","Trace the cell you want to analyze");
	run("Fit Spline");
	roiManager("Add");	
	roiManager("Interpolate ROIs");	
	Stack.setSlice(1);	
	run("Select None");	


	//-----------------------------------------------------------------------------------------------------------------
	// In order to calculate the area and intensity of each ring, slice the image into concentric polygons of increasing size. 
	// As a somewhat hacky solution, clear outside of the selected slice, jump to the next slice (j+1), and clear a portion of the image the size of j.
	// so for j = 0 (ROI 0), we clear everything outside the nucleus (which stays). I don't know if it's necessary or not--but better to keep it.
	// Ignore the values later in the analysis if unwanted.
	// When we then iterate to the next value of j, we clear inside and now that gives a ring of intensity values surrounded by 0 value background
	// If N_rings = 255, then Roi #254 corresponds to the second to last slice 
	// The images are 1-indexed but the ROIs are 0-indexed.
	// This will give a stack with a nucleus in the first slice, 254 ring slices, and 1 final slice that has not been cropped..we'll handle that below.
	
	for(channel = 1; channel <= N_channels; channel++){
		C_str = "C" + channel;
		selectWindow(C_str);
		resetMinAndMax();
		
		run("Add...", "value=1 stack"); // This will be important later to ensure that there are no 0 value pixels in the signal. 0 value will thus just be cropped background.  
		
		for (j=0; j < n_slices; j++) {
			roiManager("Select", j);
			run("Clear Outside", "slice");
			run("Next Slice [>]");
			run("Clear", "slice");
			}
		
		// This will clear the final area outside of the final slice to complete the picture
		roiManager("Select", n_slices);
		run("Clear Outside", "slice");
	
		run("32-bit"); // making it 32 bit so we can convert the 0 to nan background
		setThreshold(1, 4294967295, "raw"); // Your background is always 0 and foreground is > 0.
		run("NaN Background", "stack"); // Make the background not a number
		run("Subtract...", "value=1 stack"); // Correct for the +1 earlier
		im_for_stats = getTitle();
		run("Statistics"); // Get stats (ignores NaNs) to get min and max values for the whole stack to set the display for the eventual 8 bit conversion
		MaxValue = getResult("Max", 0);
		print(MaxValue);
		MinValue = getResult("Min",0);
		print(MinValue);
		setMinAndMax(MinValue, MaxValue);
		Table.rename("Results", C_str + "ThresholdedStackRawIntDen"); // This has the max and min info...we don't really need it but I wanted to rename the table
		
		//-----------
		selectWindow(im_for_stats);
		run("Measure Stack...");
		Table.rename("Results", C_str + "_IntensityInformation");
		saveAs("results", dir_measurements + filebase + "_"+ C_str + "_Intensity.csv"); // This is the good stuff with intensity values.  You really only need to set area and integrated.
		
		if (want_color_coding) {
			selectWindow(C_str);
			
			run("8-bit"); // Sets the display range of the active image to min and max
			
			run("Temporal-Color Code", "lut=" + lut_for_color_coding + " start=1 end=" + N_rings);
			rename("Colored_" + C_str); // useful for later concatenation
			
			if (N_channels == 1){ // not possible in the current iteration of this code since it needs multi-channel data
				saveAs("Tiff", dir_color_coded + File.separator + filebase + "_ColorCoded");
			}
		}
	}
	
	if (want_color_coding){
		cmd_concat = buildConcatenateStringFromC(N_channels, "Colored_C");
		run("Concatenate...", cmd_concat);
		saveAs("Tiff", dir_color_coded + File.separator + filebase + "_ColorCoded");
	}
	

	cmd_concat = buildConcatenateStringFromC(N_channels, "C");
	run("Concatenate...", cmd_concat);
	run("Stack to Hyperstack...", "order=xyctz channels=" + N_channels + " slices=" + N_rings + " frames=1 display=Composite");
	saveAs("Tiff", dir_cropped + File.separator + filebase + "_Cropped");
	
	roiManager("Save", dir_rois + File.separator + filebase + "_All.zip")
	
	// clean up
	close("*");
}

setBatchMode(false);