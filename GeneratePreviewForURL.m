/*
 *  Written by Jakub Husak (q_h@o2.pl)
 *  under the GNU Public License V2
 *
 */
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Cocoa/Cocoa.h>

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */
#include "atari.h"
#include "atrUtil.h"

#include "atrMount.h"
#include "atrErr.h"
#define COLUMNS 3
char * dosarr[]=DOS_ARR;
void addLine(char *line,NSString **result,NSSize *resultSize);

NSString *getUrlPath(CFURLRef url)
{
	// return path component of a URL
	NSString *path = [[(NSURL *)url absoluteURL] path];
	return [path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}


#define CharWidth    8
#define CharHeight   9
#define BorderWidth  8
#define BorderHeight 8

void addLine(char *line,NSString **result,NSSize *resultSize)
{
	// fix encoding
	int i,l=strlen(line);
	for(i=0;i<l;i++) {
		unsigned char c = (unsigned char)line[i];
		// fix non-breaking space
		if(c==0xa0)
			line[i] = 0x20;
		// fix soft hyphen
		else if(c==0xad)
			line[i]=0xed;
	}
	
	// convert Latin1 to NSString
	NSString *lineString = [NSString stringWithCString:line encoding:NSISOLatin1StringEncoding];
	if(*result == nil)
		*result = lineString;
	else
		*result = [*result stringByAppendingString:lineString];
    
	// update size of output area
	resultSize->height += CharHeight; // font height
	int width = strlen(line) * CharWidth;
	if(resultSize->width < width)
		resultSize->width = width;
}

void ADos2HostSpaced( char* host, unsigned char* aDos )
{
	char name[ 9 ];
	char ext[ 4 ];
	
	strncpy( name, (const char *) aDos, 8 );
	name[ 8 ] = '\0';
	
	strncpy( ext, (const char *) aDos + 8, 3 );
	ext[ 3 ] = '\0';
	
	strcpy( host, name );
	
	if ( *ext )
	{
		strcat( host, "." );
		strcat( host, ext );
	}
}


NSString* TransformATRDataToHtml(CFBundleRef bundle,  CFURLRef url)
{
	NSSize canvasSize;
	canvasSize.height=100;
	canvasSize.width=100;
	
	// get bundle resource path
	CFURLRef resDirURL = CFBundleCopyResourcesDirectoryURL(bundle);
	NSString *resPath = getUrlPath(resDirURL);
	CFRelease(resDirURL);
	
	
	// read template.html
	NSString *templPath = [resPath stringByAppendingPathComponent:@"template.html"];
	NSData *templateData = [NSData dataWithContentsOfFile:templPath];
	NSString *templateString = [[NSString alloc] initWithData:templateData
													 encoding:NSUTF8StringEncoding];
	NSString *templFatalPath = [resPath stringByAppendingPathComponent:@"fataltemplate.html"];
	NSData *templateFatalData = [NSData dataWithContentsOfFile:templFatalPath];
	NSString *templateFatalString = [[NSString alloc] initWithData:templateFatalData
													 encoding:NSUTF8StringEncoding];
	
	
	NSString * contents = nil;
	NSString * summary  = nil;
	NSString * fname = nil;
	NSString * finfo = nil;
	
	//	atrMount(getUrlPath(url))
	int result;
	int dosType;
	int readWrite;
	int writeProtect;
	char status [80];
	AtrDiskInfo * info;
	NSString * path=getUrlPath(url);
	
	NSArray * myArray = [[path componentsSeparatedByString: @"/"] retain ];
	NSString * fileName = (NSString*)[myArray lastObject];
	
	[ myArray release ];
	
	fname = fileName;
	// contents = path;
	const char * cpath = [ path UTF8String ] ;
	
	result = AtrMount(cpath, &dosType, 
					  &readWrite, &writeProtect, &info);
	if (result) {
		NSString *resultString = templateFatalString;
		resultString = [resultString stringByReplacingOccurrencesOfString:@"FILE_NAME"
															   withString:fname];
		addLine("Not an Atari DOS disk image file!",&contents,&canvasSize);
		resultString = [resultString stringByReplacingOccurrencesOfString:@"FILE_INFO"
															   withString:contents];
		return resultString;
	}

	// addLine(cpath,&contents,&canvasSize); 
	sprintf(status, "<br>Type: %s\tReadWrite: %s\tWriteProtect: %s<br>",dosarr[dosType],readWrite?"On":"Off", writeProtect?"On":"Off"); 
	addLine(status,&finfo,&canvasSize);
	
	
	ADosFileEntry files[1000];
	ADosFileEntry * de;
	UWORD fileCount;
	unsigned int freeBytes;
	
	AtrGetDir(info, &fileCount, files, 
			  &freeBytes);
	sprintf(status, "Sectors: %d\tSectorSize: %d<br>",
			info->atr_sectorcount,
			info->atr_sectorsize
);
	
	addLine(status,&finfo,&canvasSize);
	int i;
	char fnamebuf[20];
	int filesincol=(fileCount+COLUMNS-1)/COLUMNS;
	for (i=0; i<filesincol * COLUMNS; i++) {
		
		int ind=(i%COLUMNS)*filesincol+(i/COLUMNS);
		de=&files[ind];

		if (ind<fileCount) {
			switch(de->flags) {
				case DIRE_SUBDIR:
					fnamebuf[0]=':'; 
					break;
				case DIRE_LOCKED:
					fnamebuf[0]='*';
					break;
				default:
					fnamebuf[0]=' ';
			}
			ADos2HostSpaced( &fnamebuf[1], de->aname);
			sprintf(&fnamebuf[13], "  %03d\t",de->sectors);
			addLine(fnamebuf,&contents,&canvasSize);
		}
		if ((i%COLUMNS)==COLUMNS-1)
		addLine("<br>",&contents,&canvasSize);
		
	}

	sprintf(status, "Files: %d\tFree sectors  : %d<br>",
			fileCount,
			freeBytes/info->atr_sectorsize );
	addLine(status,&summary,&canvasSize);
	
	
	AtrUnmount(info);
	
	NSString *resultString = templateString;
	resultString = [resultString stringByReplacingOccurrencesOfString:@"FILE_NAME"
                                                           withString:fname];

	resultString = [resultString stringByReplacingOccurrencesOfString:@"FILE_INFO"
                                                           withString:finfo];

	if (contents == nil) contents = @"No files on Disk";
	resultString = [resultString stringByReplacingOccurrencesOfString:@"DIR_CONTENTS"
                                                           withString:contents];
	resultString = [resultString stringByReplacingOccurrencesOfString:@"DIR_SUMMARY"
                                                           withString:summary];
	// return data of string
	return resultString;
}

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
   	NSAutoreleasePool * pool = [[ NSAutoreleasePool alloc ] init ];
	
	CFBundleRef bundle = QLPreviewRequestGetGeneratorBundle(preview);

	NSString * html = TransformATRDataToHtml(bundle, (CFURLRef)  url);
	NSMutableDictionary * props = [[[NSMutableDictionary alloc ] init ] autorelease ] ;
	[props setObject:@"UTF-8"  forKey:(NSString *) kQLPreviewPropertyTextEncodingNameKey ];
	[props setObject:@"text/html"  forKey:(NSString *) kQLPreviewPropertyMIMETypeKey ];
	QLPreviewRequestSetDataRepresentation(preview,
										  (CFDataRef) [html dataUsingEncoding:NSUTF8StringEncoding],
										  kUTTypeHTML,
										  (CFDictionaryRef) props);
	[ pool release ] ;
	return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
