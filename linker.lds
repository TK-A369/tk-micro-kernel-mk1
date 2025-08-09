ENTRY(kmain)

SECTIONS
{
	. = ALIGN(CONSTANT(MAXPAGESIZE));
	.text : {
		*(.text .text.*)
	}
}
