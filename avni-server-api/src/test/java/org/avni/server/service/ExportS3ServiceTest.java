package org.avni.server.service;

import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import java.io.File;

import static org.junit.Assert.*;

public class ExportS3ServiceTest {
    @Mock private S3Service s3Service;
    private ExportS3Service service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new ExportS3Service(s3Service);
    }
    
    @Test
    public void testGetLocalExportFile() {
        File file = service.getLocalExportFile("test-uuid");
        assertNotNull(file);
        assertTrue(file.getPath().contains("test-uuid"));
        assertTrue(file.getPath().endsWith(".csv"));
    }
}
