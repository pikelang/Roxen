//   $Id: Dims.pmod,v 1.1 1998/01/24 17:58:11 js Exp $
//
//   Imagedimensionreadermodule for Pike.
//   Created by Johan Schön, <js@idonex.se>.
//
//   This software is based in part on the work of the Independent JPEG Group.


#define M_SOF0  0xC0		/* Start Of Frame N */
#define M_SOF1  0xC1		/* N indicates which compression process */
#define M_SOF2  0xC2		/* Only SOF0-SOF2 are now in common use */
#define M_SOF3  0xC3
#define M_SOF5  0xC5		/* NB: codes C4 and CC are NOT SOF markers */
#define M_SOF6  0xC6
#define M_SOF7  0xC7
#define M_SOF9  0xC9
#define M_SOF10 0xCA
#define M_SOF11 0xCB
#define M_SOF13 0xCD
#define M_SOF14 0xCE
#define M_SOF15 0xCF
#define M_SOI   0xD8		/* Start Of Image (beginning of datastream) */
#define M_EOI   0xD9		/* End Of Image (end of datastream) */
#define M_SOS   0xDA		/* Start Of Scan (begins compressed data) */
#define M_COM   0xFE		/* COMment */

class dims
{
  object f;

  int read_1_byte()
  {
    return f->read(1)[0];
  }  

  int read_2_bytes()
  {
    int c1=read_1_byte();
    int c2=read_1_byte();
    return ((c1<<8)+c2);
  }

  int read_2_bytes_intel()
  {
    int c1=read_1_byte();
    int c2=read_1_byte();
    return ((c2<<8)+c1);
  }

  /*
   * Read the initial marker, which should be SOI.
   * For a JFIF file, the first two bytes of the file should be literally
   * 0xFF M_SOI.  To be more general, we could use next_marker, but if the
   * input file weren't actually JPEG at all, next_marker might read the whole
   * file and then return a misleading error message...
   */

  int first_marker()
  {
    int c1, c2;
    
    c1 = read_1_byte();
    c2 = read_1_byte();
    if (c1!=0xFF||c2!=M_SOI) return 0;
    return c2;
  }

  /*
   * Find the next JPEG marker and return its marker code.
   * We expect at least one FF byte, possibly more if the compressor used FFs
   * to pad the file.
   * There could also be non-FF garbage between markers.  The treatment of such
   * garbage is unspecified; we choose to skip over it but emit a warning msg.
   * NB: this routine must not be used after seeing SOS marker, since it will
   * not deal correctly with FF/00 sequences in the compressed image data...
   */

  int next_marker()
  {
    int c;
    int discarded_bytes = 0;
    
    /* Find 0xFF byte; count and skip any non-FFs. */
    c = read_1_byte();
    while (c != 0xFF) {
      discarded_bytes++;
      c = read_1_byte();
    }
    /* Get marker code byte, swallowing any duplicate FF bytes.  Extra FFs
     * are legal as pad bytes, so don't count them in discarded_bytes.
     */
    do {
      c = read_1_byte();
    } while (c == 0xFF);
    return c;
  }

  /* Skip over an unknown or uninteresting variable-length marker */
  int skip_variable()
  {
    int length = read_2_bytes();
//    werror("Skip length: "+length+"\n");
    if (length < 2) return 0;  /* Length includes itself, so must be at least 2 */
    length -= 2;
    f->seek(f->tell()+length);
    return 1;
  }

  
  array get_JPEG()
  {
    int marker;
    f->seek(0);
    /* Expect SOI at start of file */
    if (first_marker() != M_SOI)
      return 0;
    
    /* Scan miscellaneous markers until we reach SOS. */
    for (;;)
    {
      marker = next_marker();
      switch (marker) {
       case M_SOF0:		/* Baseline */
       case M_SOF1:		/* Extended sequential, Huffman */
       case M_SOF2:		/* Progressive, Huffman */
       case M_SOF3:		/* Lossless, Huffman */
       case M_SOF5:		/* Differential sequential, Huffman */
       case M_SOF6:		/* Differential progressive, Huffman */
       case M_SOF7:		/* Differential lossless, Huffman */
       case M_SOF9:		/* Extended sequential, arithmetic */
       case M_SOF10:		/* Progressive, arithmetic */
       case M_SOF11:		/* Lossless, arithmetic */
       case M_SOF13:		/* Differential sequential, arithmetic */
       case M_SOF14:		/* Differential progressive, arithmetic */
       case M_SOF15:		/* Differential lossless, arithmetic */
	int length = read_2_bytes();	/* usual parameter length count */
	int data_precision = read_1_byte();
	int image_height = read_2_bytes();
	int image_width = read_2_bytes();
	return ({ image_width,image_height });
	break;
	
       case M_SOS:			/* stop before hitting compressed data */
	return 0;
	
       case M_EOI:			/* in case it's a tables-only JPEG stream */
	return 0;
	
       default:			/* Anything else just gets skipped */
	if(!skip_variable()) return 0;   /* we assume it has a parameter count... */
	break;
      }
    } 
  }

// GIF-header:
// typedef struct _GifHeader
// {
//   // Header
//   BYTE Signature[3];     /* Header Signature (always "GIF") */
//   BYTE Version[3];       /* GIF format version("87a" or "89a") */
//   // Logical Screen Descriptor
//   WORD ScreenWidth;      /* Width of Display Screen in Pixels */
//   WORD ScreenHeight;     /* Height of Display Screen in Pixels */
//   BYTE Packed;           /* Screen and Color Map Information */
//   BYTE BackgroundColor;  /* Background Color Index */
//   BYTE AspectRatio;      /* Pixel Aspect Ratio */
// } GIFHEAD;

  array get_GIF()
  {
    int marker;
    f->seek(0);
    if(f->read(3)!="GIF") return 0;
    f->seek(6);
    int image_width = read_2_bytes_intel();
    int image_height = read_2_bytes_intel();
    return ({ image_width, image_height });
  }

  array get_PNG()
  {
    int marker;
    f->seek(1);
    if(f->read(3)!="PNG") return 0;
    f->seek(12);
    if(f->read(4)!="IHDR") return 0;
    read_2_bytes();
    int image_width = read_2_bytes();
    read_2_bytes_intel();
    int image_height = read_2_bytes();
    return ({ image_width, image_height });
  }

  // Read dimensions from a JPEG or GIF file and either return an array with
  // width and height or 0.
  array get(string fn)
  {
    f=Stdio.File(fn,"r");
    array a;
    catch {
      if(a=get_JPEG())
	return a;
      else if (a=get_GIF())
	return a;
      else if (a=get_PNG())
	return a;
      else
	return 0;
    };
    return 0;
  }
}
