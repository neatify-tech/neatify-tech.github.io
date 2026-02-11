export {};
const outerConditionNameThatForcesWrapping=true;
const anotherOuterConditionNameThatForcesWrapping=true;
const tailConditionNameThatForcesWrapping=true;
const veryLongInnerConditionNameThatExceedsWidthOne=true;
const veryLongInnerConditionNameThatExceedsWidthTwo=true;
const veryLongInnerConditionNameThatExceedsWidthThree=true;
const shortA=true;
const shortB=false;
function go() { return; }
if (outerConditionNameThatForcesWrapping && (veryLongInnerConditionNameThatExceedsWidthOne && veryLongInnerConditionNameThatExceedsWidthTwo && veryLongInnerConditionNameThatExceedsWidthThree) && tailConditionNameThatForcesWrapping) { go(); }
if (outerConditionNameThatForcesWrapping && (shortA && shortB) && anotherOuterConditionNameThatForcesWrapping) { go(); }
