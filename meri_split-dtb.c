/*
 * Copyright 2017 Brian Starkey <stark3y@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Splits the monolithic, multi-target dtb into its component dtb parts, by
 * looking for dtb magic headers
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdint.h>
#include <fcntl.h>

int main(int argc, char *argv[])
{
	int fd, ret, i = 0;
	char filename[128];
	uint8_t *p;
	struct stat s;
	size_t len;
	off_t off = 0;
	uint8_t magic[] = { 0xd0, 0x0d, 0xfe, 0xed };

	if (argc != 2) {
		fprintf(stderr, "Usage: %s infile\n"
			"\tSplit a multi-dtb file at d00dfeed delimiters\n",
			argv[0]);
		return 1;
	}

	ret = stat(argv[1], &s);
	if (ret != 0) {
		fprintf(stderr, "stat error. %s\n", strerror(errno));
		return 1;
	}
	len = s.st_size;

	fd = open(argv[1], O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "open error. %s\n", strerror(errno));
		return 1;
	}

	p = mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, 0);
	if (p == MAP_FAILED) {
		fprintf(stderr, "mmap error. %s\n", strerror(errno));
		ret = 1;
		goto done;
	}

	while (off < len) {
		if ((p[0] == magic[0]) &&
		    (p[1] == magic[1]) &&
		    (p[2] == magic[2]) &&
		    (p[3] == magic[3])) {
			int fd2;
			snprintf(filename, 128, "%s.%d", argv[1], i++);
			printf("Writing %s\n", filename);

			fd2 = open(filename, O_CREAT | O_RDWR);
			if (fd2 < 0) {
				fprintf(stderr, "open error. %s\n", strerror(errno));
				ret = 1;
				goto done;
			}

			if (write(fd2, p, len - off) != len - off) {
				fprintf(stderr, "write error. %s\n", strerror(errno));
				ret = 1;
				close(fd2);
				goto done;
			}

			close(fd2);
		}
		off++;
		p++;
	}

done:
	close(fd);
	return ret;
}

