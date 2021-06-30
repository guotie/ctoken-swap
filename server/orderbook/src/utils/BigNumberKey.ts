import { BigNumber, BigNumberish } from 'ethers'
import { IComparable } from 'tstl'

export default class BigNumberKey implements IComparable<BigNumberKey> {
  val: BigNumber

  constructor(b: BigNumberish) {
    this.val = BigNumber.from(b)
  }

  static from(v: BigNumberish) {
    return new BigNumberKey(v)
  }

  equals(t: BigNumberKey) {
    return this.val.eq(t.val)
  }

  less(t: BigNumberKey) {
    return this.val.lt(t.val)
  }

  hashCode() {
    return 10000
  }
}
