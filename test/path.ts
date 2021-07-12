
// [[a,b], [a,c,b], [a,d,b]]
let pathes: string[][] = []

function combination(token1: string, complex: number, midTokens: string[], path: string[]) {
    let npath = []
    for (let item of path) {
        npath.push(item)
    }
    if (complex === 0) {
        npath.push(token1)
        pathes.push(npath)
        return
    }
    // 
    for (let token of midTokens) {
        npath.push(token)
        let nMidTokens = []
        for (let token of midTokens) {
            if (npath.indexOf(token) === -1) {
                nMidTokens.push(token)
            }
        }
        combination(token1, complex-1, nMidTokens, npath)
        npath.pop()
    }
}


// 测试 swap router
describe("path 排列组合 测试", function() {
    it('排列组合1', () => {
        let complex = 3
        combination('b', complex, ['m0', 'm1', 'm2'], ['a'])
        console.log('排列(complex=%d):', complex, pathes)
    })
})