"""Run the checked-in Swift test methods synchronously when SwiftPM is unavailable.
The production sources and test bodies are unchanged; this adapter replaces the
XCTest runner/assertion surface to avoid Linux runner background-thread failures.
Usage: python scripts/run_core_checks.py /path/to/swift-frontend [clang-include-dir]
"""
from pathlib import Path
import re,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]/'Unscroll_Xcode_V1'
s='''import Foundation
class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) {
    if a != b { fatalError("Expected \\(b), got \\(a) at \\(file):\\(line)") }
}
func XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    if !a.isFinite || abs(a-b) > accuracy { fatalError("Expected \\(b), got \\(a) at \\(file):\\(line)") }
}
func XCTAssertNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    if value != nil { fatalError("Expected nil at \\(file):\\(line)") }
}
'''
s += r"""
func XCTAssertTrue(_ value: Bool) { if !value { fatalError("Expected true") } }
func XCTAssertFalse(_ value: Bool) { if value { fatalError("Expected false") } }
func XCTAssertNotNil<T>(_ value: T?) { if value == nil { fatalError("Expected non-nil") } }
func XCTUnwrap<T>(_ value: T?) throws -> T { guard let value else { fatalError("Expected non-nil") }; return value }
"""
s+='\n'.join(p.read_text() for p in sorted((root/'Core').glob('*.swift')))
calls=[]
for p in sorted((root/'Tests/UnscrollCoreTests').glob('*.swift')):
    t=p.read_text().replace('import XCTest','').replace('@testable import UnscrollCore','')
    s+='\n'+t
    cls=re.search(r'final class (\w+)',t).group(1)
    for name,throws in re.findall(r'func (test\w+)\(\)\s*(throws)?',t):
        calls.append(('try ' if throws else '')+cls+'().'+name+'(); print("PASS '+cls+'.'+name+'")')
s+='\n'+'\n'.join(calls)+'\nprint("All '+str(len(calls))+' core checks passed")\n'
with tempfile.TemporaryDirectory() as tmp:
    p=Path(tmp)/'core-checks.swift';p.write_text(s)
    cmd=[sys.argv[1],'-interpret']
    if len(sys.argv)>2:cmd+=['-Xcc','-I'+sys.argv[2]]
    subprocess.run(cmd+[str(p)],check=True)
