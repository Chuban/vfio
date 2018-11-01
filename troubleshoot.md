# Troubleshooting

## QEMU can not allocate memory

```
qemu-system-x86_64: VFIO_MAP_DMA: -12                                       
qemu-system-x86_64: vfio_dma_map(0x7fae44695a00, 0xc0000000, 0x40000, 0x7fab29e00000) = -12 (Cannot allocate memory)
qemu: hardware error: vfio: DMA mapping failed, unable to continue
```

Solution:
```
ulimit -l $(( $(echo $RAM | tr -d 'G')*1048576+10 ))
```

Note: This is already addressed in the `windows.sh` script.
