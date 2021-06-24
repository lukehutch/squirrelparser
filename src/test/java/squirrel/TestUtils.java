//
// This file is part of the squirrel parser reference implementation:
//
//     https://github.com/lukehutch/squirrelparser
//
// This software is provided under the MIT license:
//
// Copyright 2021 Luke A. D. Hutchison
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
package squirrel;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Objects;
import java.util.function.Function;

public class TestUtils {
    public static String loadResourceFile(String filename) {
        try {
            final var resource = TestUtils.class.getClassLoader().getResource(filename);
            final var resourceURI = Objects.requireNonNull(resource).toURI();
            return Files.readString(Paths.get(resourceURI));
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    // Execute 5x, and find the minimum execution time, to try to remove the effect of GC and other hiccups
    public static long findMinTime(Function<String, Long> timerFunction, String input) {
        long minTime = Long.MAX_VALUE;
        for (int i = 0; i < 5; i++) {
            var time = timerFunction.apply(input);
            minTime = Math.min(minTime, time);
        }
        return minTime;
    }
}
