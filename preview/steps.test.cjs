const test=require('node:test');const assert=require('node:assert/strict');const U=require('./model.js');
test('three modes apply to repetitions, full plank blocks and steps',()=>{
 for(const [mode,ratio] of Object.entries({beginner:3,normal:2,hard:1})){
  const s=U.fresh();Object.assign(s.profile,{mode,ratio});
  for(const e of ['pushups','squats','situps'])assert.equal(U.reward(s,e,4),4*ratio);
  assert.equal(U.reward(s,'plank',29),0);assert.equal(U.reward(s,'plank',30),ratio);assert.equal(U.reward(s,'plank',65),ratio*2);
  U.updateSteps(s,999);assert.equal(U.claimSteps(s),0);U.updateSteps(s,2500);assert.equal(U.claimSteps(s),2*ratio);
 }
});
test('step claims survive reload, downward readings and mode changes without duplication',()=>{
 const s=U.fresh();s.profile.mode='beginner';s.profile.ratio=3;const now=new Date();U.updateSteps(s,2000,now);assert.equal(U.claimSteps(s,now),6);
 const restored=U.load({getItem:()=>JSON.stringify(s)});assert.equal(U.claimSteps(restored,now),0);
 restored.profile.mode='hard';restored.profile.ratio=1;U.updateSteps(restored,1500,now);assert.equal(U.claimSteps(restored,now),0);
 U.updateSteps(restored,3000,now);assert.equal(U.claimSteps(restored,now),1);assert.equal(restored.bank,7);
 const tomorrow=new Date(now);tomorrow.setDate(tomorrow.getDate()+1);U.updateSteps(restored,1000,tomorrow);assert.equal(U.claimSteps(restored,tomorrow),1);
 assert.equal(U.stepDay(restored,now).minutes,7);assert.throws(()=>U.updateSteps(restored,-1));
});
test('legacy preview retains balance and completed profile',()=>{
 const s=U.fresh();delete s.profile.mode;delete s.profile.configured;delete s.stepDays;s.profile.name='Sam';s.profile.ratio=1;s.bank=42;
 const restored=U.load({getItem:()=>JSON.stringify(s)});assert.equal(restored.bank,42);assert.equal(restored.profile.mode,'hard');assert.equal(restored.profile.configured,true);assert.equal(U.stepDay(restored).steps,0);
});
