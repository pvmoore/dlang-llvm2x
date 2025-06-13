	.def	@feat.00;
	.scl	3;
	.type	0;
	.endef
	.globl	@feat.00
.set @feat.00, 0
	.file	"test"
	.def	foo;
	.scl	2;
	.type	32;
	.endef
	.text
	.globl	foo
	.p2align	4
foo:
.seh_proc foo
	subq	$40, %rsp
	.seh_stackalloc 40
	.seh_endprologue
	movl	$90, %ecx
	callq	putchar
	nop
	addq	$40, %rsp
	retq
	.seh_endproc

	.def	main;
	.scl	2;
	.type	32;
	.endef
	.globl	main
	.p2align	4
main:
.seh_proc main
	subq	$40, %rsp
	.seh_stackalloc 40
	.seh_endprologue
	leaq	foo(%rip), %rax
	movl	$65, %ecx
	movq	%rax, 32(%rsp)
	callq	*%rax
	xorl	%eax, %eax
	addq	$40, %rsp
	retq
	.seh_endproc

