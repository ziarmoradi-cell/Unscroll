const test = require('node:test');
const assert = require('node:assert/strict');
const U = require('./model.js');
test('exercise earns shared balance once per workout', () => {
  const s=U.fresh(); U.earn(s,'pushups',10,'one'); U.earn(s,'pushups',10,'one'); assert.equal(s.bank,10); assert.equal(s.workouts.length,1);
});
test('shared usage across apps consumes one balance and blocks at zero',()=>{
  const s=U.fresh();U.earn(s,'pushups',10);U.start(s);assert.equal(s.bank,0);U.consume(s,4);U.consume(s,3);assert.equal(U.current(s).total-U.current(s).used,3);U.consume(s,3);assert.equal(U.current(s),null);assert.throws(()=>U.consume(s,1));
});
test('new earnings during active session are kept for next release',()=>{
  const s=U.fresh();U.earn(s,'squats',5);U.start(s);U.earn(s,'situps',4);U.consume(s,5);assert.equal(s.bank,4);assert.equal(U.start(s).total,4);
});
test('emergency counted once and active session prevents another',()=>{
  const s=U.fresh();U.start(s,true);assert.equal(s.emergency,1);assert.throws(()=>U.start(s,true));assert.equal(s.emergency,1);U.consume(s,5);assert.equal(U.week(s).emergency,1);
});
test('reload preserves active session as single ledger record',()=>{
  const s=U.fresh();U.earn(s,'pushups',10);U.start(s);U.consume(s,3);
  let text='';const storage={setItem(k,v){text=v},getItem(){return text}};U.save(storage,s);const restored=U.load(storage);assert.equal(U.current(restored).used,3);U.consume(restored,2);assert.equal(restored.usage[0].used,5);assert.equal(U.week(restored).used,5);
});
test('plank reward rounds down to completed earning units',()=>{
  const s=U.fresh();assert.equal(U.earn(s,'plank',29),2);assert.equal(s.bank,2);assert.throws(()=>U.earn(s,'pushups',-1));
});
test('early stop does not refund an uncertain balance',()=>{
  const s=U.fresh();U.earn(s,'squats',8);U.start(s);U.consume(s,2);U.stop(s);assert.equal(s.bank,0);assert.equal(U.week(s).used,2);
});
test('invalid stored data resets safely',()=>{
  assert.equal(U.load({getItem(){return '{invalid'}}).bank,0);
  assert.equal(U.load({getItem(){return JSON.stringify({...U.fresh(),bank:-8})}}).bank,0);
});
test('no apps means no release or emergency count',()=>{
  const s=U.fresh();s.apps=[];assert.throws(()=>U.start(s,true));assert.equal(s.emergency,0);
});
