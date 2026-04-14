# Linux Kernel

<details>
<summary>Expand for details...</summary>

- Kernel Paramaters:
  - https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/kernel-parameters.txt
 
- KVM MSRs
  - https://docs.kernel.org/virt/kvm/x86/msr.html
  - https://github.com/torvalds/linux/blob/master/arch/x86/include/uapi/asm/kvm_para.h

</details>

---










# QEMU/KVM (Emulator)

<details>
<summary>Expand for details...</summary>

## KVM-specific Custom MSR/Signatures

> Reference: [`kvm_para.h`](https://gitlab.com/qemu-project/qemu/-/blob/master/include/standard-headers/asm-x86/kvm_para.h)

## Hypervisor Bit

Clears `CPUID.1.ECX[31]` - the universal "hypervisor present" indicator.

```bash
qemu-system-x86_64 -cpu host,-hypervisor
```
```xml
  <cpu>
    <feature policy="disable" name="hypervisor"/>
