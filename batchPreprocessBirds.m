function [] = batchPreprocessBirds()

preprocessBirdsData_NEV('CUBF22','/media/elliot/Data_B/Birds/CUBF22/rawData')
preprocessBirdsData_NEV('CUBF26','/media/elliot/Data_B/Birds/CUBF26/rawData')
preprocessBirdsData_NEV('CUBF30','/media/elliot/Data_B/Birds/CUBF30/rawData')

% This is a reimplant of CUBF22, approx 5 months later. Nice frontal
% implant, but macros were recorded at 30 kHz
preprocessBirdsData_NEV('CUBF22_reimplant','/media/elliot/Data_B/Birds/CUBF22_reimplant/rawData')

% preprocessBirdsData_NEV('CUBF18_reimplant','/media/elliot/Data_B/Birds/CUBF18_reimplant/rawData')

end
