close all
%Percentage distance from plasma membrane to cytoplasm
xPosition=(linspace(1,255,255)')/255;

%Value spit out by Fiji - this is the area of each ring in square microns
MicronArea_Ring=Area(1:255,1);

%Sum of the rings for total cytoplasmic area in square microns
MicronArea_Total=sum(MicronArea_Ring(1:255,1))

%The relationship between the intedgrated densty and the raw integrated
%density gives the number of pixels in 1 um2
SquarePixel_perSquareMicron = RawIntDen(1)/IntDen(1);
PixelArea_Ring=MicronArea_Ring.*SquarePixel_perSquareMicron;
%PixelArea_Total=sum(PixelArea_Ring(1:255,1));
PixelArea_Total=MicronArea_Total.*SquarePixel_perSquareMicron; 

%SimpleRatioNormalization

for p=1:255
    RatioFrac = PixelArea_Ring(1)./PixelArea_Ring(p);
    RatioScaled(p,1)=RatioFrac;
end


%Area corrected
CorrectedPixelArea = PixelArea_Ring.*RatioScaled;
figure
plot(xPosition,PixelArea_Ring);
hold on
plot(xPosition,CorrectedPixelArea,'r')
title("Correcting ring size");

%Integrated density
RawDensity=RawIntDen(1:255,1);

%Corrected density
CorrectedDensity=RawIntDen(1:255,1).*RatioScaled;

%Sum of corrected density
SumCorrectedDensity=sum(CorrectedDensity);

%Corrected Fractional Density
CorFracDens=CorrectedDensity./SumCorrectedDensity;

%CumulativeCorrectedDensity
for p=1:255
    CumulativeCorrectedDensity (p,1) = sum(CorrectedDensity(1:p));
end

%CDF ratio
CDFRatio=CumulativeCorrectedDensity/SumCorrectedDensity;



%Here there be trapezodial numerical integration
Q=trapz(CorFracDens);
D=cumtrapz(CorFracDens);
B=find(D<0.5000);
BB=length(B)
Low50=D(BB);
C=find(D>0.5000);
CC=C(1);
High50=D(CC);

if sqrt(.5^2+Low50^2)^2>sqrt(.5^2+High50^2)^2
    MidPoint=xPosition(BB)
else 
    MidPoint=xPosition(CC)
end

xValueOfMidpont=MidPoint*255;


%So the CorFracDensity is prob the most imporatnt output




%Here there be graphs
figure
hold on
plot(xPosition,RawDensity)
plot(xPosition,CorrectedDensity,'r') 
xline(MidPoint)
xlabel('Distance from nuclear envelope')
ylabel("Raw Intensity")
title("CorrectedRawIntensity");

figure
plot(xPosition,CorFracDens)
xline(MidPoint)
title("CorrectedFractionalDensity")
xlabel('Distance from nuclear envelope')
ylabel("Density")

figure
plot(xPosition,CDFRatio)
yline(.5)
xlabel('Distance from nuclear envelope')
ylabel('Cumulative intensity')
title("Cumulative Density")

%plot(xPosition,Mean(1:255,1))
%xlabel('Distance from nuclear envelope')
%ylabel("average intensity")
%title("MeanIntensity");


