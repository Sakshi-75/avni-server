package org.avni.server.service.exception;

import org.junit.Test;
import static org.junit.Assert.*;

public class GroupNotFoundExceptionTest {
    @Test
    public void testDefaultConstructor() {
        GroupNotFoundException exception = new GroupNotFoundException();
        assertNotNull(exception);
    }
    
    @Test
    public void testConstructorWithMessage() {
        GroupNotFoundException exception = new GroupNotFoundException("Group not found");
        assertEquals("Group not found", exception.getMessage());
    }
}
